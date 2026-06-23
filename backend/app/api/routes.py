from datetime import datetime
from pathlib import Path
from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Body, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.config import get_settings
from app.core.deps import GLOBAL_ACCESS_ROLES, ensure_project_access, get_current_user, require_roles, role_name
from app.core.security import create_access_token, hash_password, verify_password
from app.db.session import get_db
from app.models.entities import (
    AuditLog,
    Collection,
    CollectionAnswer,
    CollectionPhoto,
    Form,
    FormField,
    FormVersion,
    Project,
    ProjectForm,
    ProjectUser,
    Role,
    Section,
    SyncLog,
    User,
    UserForm,
    WorkPoint,
    new_id,
)
from app.schemas.api import (
    CollectionIn,
    CollectionOut,
    FormIn,
    FormOut,
    LoginIn,
    MobileBootstrapOut,
    MobileSyncIn,
    MobileSyncOut,
    ProjectIn,
    ProjectOut,
    SectionIn,
    SectionOut,
    TokenOut,
    UserCreate,
    UserOut,
    UserUpdate,
    WorkPointIn,
    WorkPointOut,
)
from app.services.exports import build_collection_pdf, build_collections_kmz, build_collections_xlsx


router = APIRouter()

SYSTEM_MANAGER_ROLES = ("admin", "coordinator")
MOBILE_COLLECTION_WRITER_ROLES = ("admin", "coordinator", "archaeologist")


def get_role(db: Session, role_id: str | None = None, role: str | None = None) -> Role:
    if role_id:
        db_role = db.get(Role, role_id)
    elif role:
        db_role = db.query(Role).filter_by(name=role).first()
    else:
        db_role = db.query(Role).filter_by(name="archaeologist").first()
    if not db_role:
        raise HTTPException(status_code=422, detail="Perfil inexistente")
    return db_role


def audit(db: Session, user: User | None, entity: str, entity_id: str, action: str, new_value: dict | None = None) -> None:
    db.add(
        AuditLog(
            user_id=user.id if user else None,
            entity_name=entity,
            entity_id=entity_id,
            action=action,
            new_value=new_value,
        )
    )


def visible_project_ids(db: Session, user: User) -> list[str] | None:
    if role_name(user) in GLOBAL_ACCESS_ROLES:
        return None
    return [row.project_id for row in db.query(ProjectUser).filter_by(user_id=user.id).all()]


def visible_form_ids(db: Session, user: User) -> list[str] | None:
    if role_name(user) in GLOBAL_ACCESS_ROLES:
        return None
    return [row.form_id for row in db.query(UserForm).filter_by(user_id=user.id).all()]


def ensure_form_access(db: Session, user: User, form_id: str) -> None:
    if role_name(user) in GLOBAL_ACCESS_ROLES:
        return
    exists = db.query(UserForm).filter_by(user_id=user.id, form_id=form_id).first()
    if not exists:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso ao formulario negado")


def ensure_mobile_collection_write(user: User) -> None:
    if role_name(user) not in MOBILE_COLLECTION_WRITER_ROLES:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Perfil sem permissao para enviar coletas")


def ensure_collection_update_access(user: User, collection: Collection) -> None:
    current_role = role_name(user)
    if current_role in {"admin", "coordinator"}:
        return
    if current_role == "archaeologist" and collection.user_id == user.id:
        return
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Coleta pertence a outro usuario")


def collection_query(db: Session):
    return db.query(Collection).options(
        selectinload(Collection.project),
        selectinload(Collection.form),
        selectinload(Collection.section),
        selectinload(Collection.work_point),
        selectinload(Collection.user).selectinload(User.role),
        selectinload(Collection.answers),
        selectinload(Collection.photos),
    )


def replace_project_links(db: Session, user: User, project_ids: list[str]) -> None:
    db.query(ProjectUser).filter_by(user_id=user.id).delete()
    for project_id in project_ids:
        if db.get(Project, project_id):
            db.add(ProjectUser(user_id=user.id, project_id=project_id))


def replace_form_links(db: Session, user: User, form_ids: list[str]) -> None:
    valid_form_ids = [form_id for form_id in dict.fromkeys(form_ids) if db.get(Form, form_id)]
    existing_links = {link.form_id: link for link in user.form_links}
    user.form_links = [
        existing_links.get(form_id) or UserForm(user_id=user.id, form_id=form_id)
        for form_id in valid_form_ids
    ]
    db.flush()


def replace_form_projects(db: Session, form: Form, project_ids: list[str]) -> list[str]:
    valid = [pid for pid in dict.fromkeys(project_ids) if db.get(Project, pid)]
    if not valid:
        raise HTTPException(status_code=422, detail="Informe ao menos um projeto valido para o formulario")
    db.query(ProjectForm).filter_by(form_id=form.id).delete()
    for project_id in valid:
        db.add(ProjectForm(project_id=project_id, form_id=form.id))
    form.project_id = valid[0]
    return valid


def forms_for_projects(query, project_ids: list[str]):
    """Restringe uma query de Form aos vinculados (via ProjectForm) a algum dos projetos."""
    linked = select(ProjectForm.form_id).where(ProjectForm.project_id.in_(project_ids))
    return query.filter(Form.id.in_(linked))


def validate_required_collection_fields(db: Session, payload: CollectionIn) -> None:
    form = db.get(Form, payload.form_id)
    if not form:
        raise HTTPException(status_code=422, detail="Formulario inexistente")
    fields = db.query(FormField).filter_by(form_id=form.id, version=payload.form_version).all()
    answer_map = {answer.field_key: answer.answer_value for answer in payload.answers}
    context = {
        **answer_map,
        "project_id": payload.project_id,
        "section_id": payload.section_id,
        "work_point_id": "other" if payload.work_point_other and not payload.work_point_id else payload.work_point_id,
        "work_point_other": payload.work_point_other,
        "collection_date": payload.collection_date,
        "coordinates": [payload.latitude, payload.longitude] if payload.latitude is not None and payload.longitude is not None else None,
    }
    photo_types = {photo.photo_type for photo in payload.photos}

    def is_empty(value: object) -> bool:
        return value is None or value == "" or value == []

    for field in fields:
        if not field.is_required:
            continue
        condition = field.conditional_logic
        if condition:
            target = context.get(condition.get("field"))
            expected = condition.get("value")
            if condition.get("operator") == "contains":
                if not (isinstance(target, list) and expected in target):
                    continue
            elif target != expected:
                continue
        if field.field_key == "work_point_id" and not payload.work_point_id and not payload.work_point_other:
            raise HTTPException(status_code=422, detail=f"Campo obrigatorio ausente: {field.label}")
        if field.field_key in {"project_id", "section_id", "collection_date", "coordinates"}:
            if is_empty(context.get(field.field_key)):
                raise HTTPException(status_code=422, detail=f"Campo obrigatorio ausente: {field.label}")
            continue
        if field.field_type == "photo":
            if field.field_key not in photo_types:
                raise HTTPException(status_code=422, detail=f"Foto obrigatoria ausente: {field.label}")
            continue
        if is_empty(context.get(field.field_key)):
            raise HTTPException(status_code=422, detail=f"Campo obrigatorio ausente: {field.label}")


def upsert_collection(db: Session, payload: CollectionIn, user: User, device_id: str | None = None) -> Collection:
    ensure_mobile_collection_write(user)
    ensure_project_access(db, user, payload.project_id)
    ensure_form_access(db, user, payload.form_id)
    validate_required_collection_fields(db, payload)
    collection = db.query(Collection).filter_by(local_uuid=payload.local_uuid).first()
    now = datetime.utcnow()
    if collection:
        ensure_collection_update_access(user, collection)
        db.query(CollectionAnswer).filter_by(collection_id=collection.id).delete()
        db.query(CollectionPhoto).filter_by(collection_id=collection.id).delete()
        action = "update_collection_from_mobile"
    else:
        collection = Collection(local_uuid=payload.local_uuid, server_uuid=new_id())
        db.add(collection)
        action = "create_collection_from_mobile"

    if role_name(user) in {"admin", "coordinator"}:
        owner_id = payload.user_id or collection.user_id or user.id
    else:
        owner_id = user.id

    collection.project_id = payload.project_id
    collection.form_id = payload.form_id
    collection.form_version = payload.form_version
    collection.section_id = payload.section_id
    collection.work_point_id = payload.work_point_id
    collection.work_point_other = payload.work_point_other
    collection.user_id = owner_id
    collection.collection_date = payload.collection_date
    collection.latitude = payload.latitude
    collection.longitude = payload.longitude
    collection.gps_accuracy = payload.gps_accuracy
    collection.original_latitude = payload.original_latitude
    collection.original_longitude = payload.original_longitude
    collection.coordinate_was_edited = payload.coordinate_was_edited
    collection.status = "synced"
    collection.sync_status = "synced"
    collection.created_locally_at = payload.created_locally_at
    collection.updated_locally_at = payload.updated_locally_at
    collection.synced_at = now
    db.flush()

    for answer in payload.answers:
        db.add(
            CollectionAnswer(
                collection_id=collection.id,
                field_id=answer.field_id,
                field_key=answer.field_key,
                answer_value=answer.answer_value,
            )
        )
    for photo in payload.photos:
        db.add(
            CollectionPhoto(
                collection_id=collection.id,
                field_id=photo.field_id,
                photo_type=photo.photo_type,
                file_path=photo.file_path,
                original_filename=photo.original_filename,
                mime_type=photo.mime_type,
                latitude=photo.latitude,
                longitude=photo.longitude,
                taken_at=photo.taken_at,
                photo_metadata=photo.metadata,
                sync_status="synced",
            )
        )
    db.add(
        SyncLog(
            collection_id=collection.id,
            user_id=user.id,
            device_id=device_id,
            action=action,
            status="success",
            message="Dado do celular prevaleceu e foi sincronizado.",
            payload=payload.model_dump(mode="json"),
        )
    )
    audit(db, user, "collections", collection.id, action, {"local_uuid": payload.local_uuid})
    db.flush()
    return collection


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/auth/login", response_model=TokenOut)
def login(payload: LoginIn, db: Session = Depends(get_db)) -> TokenOut:
    user = db.query(User).filter_by(email=payload.email.lower()).first()
    if not user or not user.is_active or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="E-mail ou senha invalidos")
    return TokenOut(access_token=create_access_token(user.id, role_name(user)))


@router.post("/auth/refresh", response_model=TokenOut)
def refresh(user: User = Depends(get_current_user)) -> TokenOut:
    return TokenOut(access_token=create_access_token(user.id, role_name(user)))


@router.get("/auth/me", response_model=UserOut)
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> User:
    return (
        db.query(User)
        .options(selectinload(User.role), selectinload(User.project_links), selectinload(User.form_links))
        .filter_by(id=user.id)
        .first()
    )


@router.get("/users", response_model=list[UserOut])
def list_users(_: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[User]:
    return (
        db.query(User)
        .options(selectinload(User.role), selectinload(User.project_links), selectinload(User.form_links))
        .order_by(User.name)
        .all()
    )


@router.post("/users", response_model=UserOut, status_code=201)
def create_user(
    payload: UserCreate, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> User:
    if role_name(admin) != "admin" and payload.form_ids:
        raise HTTPException(status_code=403, detail="Apenas administradores podem vincular formularios")
    if db.query(User).filter_by(email=payload.email.lower()).first():
        raise HTTPException(status_code=409, detail="E-mail ja cadastrado")
    db_role = get_role(db, payload.role_id, payload.role)
    user = User(
        name=payload.name,
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        role_id=db_role.id,
        is_active=payload.is_active,
    )
    db.add(user)
    db.flush()
    replace_project_links(db, user, payload.project_ids)
    replace_form_links(db, user, payload.form_ids)
    audit(db, admin, "users", user.id, "create_user", {"email": user.email})
    db.commit()
    db.refresh(user)
    return user


@router.get("/users/{user_id}", response_model=UserOut)
def get_user(user_id: str, _: User = Depends(get_current_user), db: Session = Depends(get_db)) -> User:
    user = (
        db.query(User)
        .options(selectinload(User.role), selectinload(User.project_links), selectinload(User.form_links))
        .filter_by(id=user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado")
    return user


@router.put("/users/{user_id}", response_model=UserOut)
def update_user(
    user_id: str, payload: UserUpdate, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> User:
    if role_name(admin) != "admin" and payload.form_ids is not None:
        raise HTTPException(status_code=403, detail="Apenas administradores podem alterar vinculos de formularios")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado")
    if payload.name is not None:
        user.name = payload.name
    if payload.email is not None:
        existing = db.query(User).filter(User.email == payload.email.lower(), User.id != user.id).first()
        if existing:
            raise HTTPException(status_code=409, detail="E-mail ja cadastrado")
        user.email = payload.email.lower()
    if payload.password is not None:
        user.password_hash = hash_password(payload.password)
    if payload.role_id or payload.role:
        user.role_id = get_role(db, payload.role_id, payload.role).id
    if payload.is_active is not None:
        user.is_active = payload.is_active
    if payload.project_ids is not None:
        replace_project_links(db, user, payload.project_ids)
    if payload.form_ids is not None:
        replace_form_links(db, user, payload.form_ids)
    audit_payload = payload.model_dump(exclude_unset=True)
    if "password" in audit_payload:
        audit_payload["password"] = "***"
    audit(db, admin, "users", user.id, "update_user", audit_payload)
    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{user_id}")
def delete_user(
    user_id: str, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> dict[str, str]:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado")
    user.is_active = False
    audit(db, admin, "users", user.id, "deactivate_user")
    db.commit()
    return {"status": "inactive"}


@router.post("/users/{user_id}/reset-password")
def reset_password(
    user_id: str,
    payload: dict | None = Body(default=None),
    admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado")
    new_password = (payload or {}).get("password", "Brandt123!")
    user.password_hash = hash_password(new_password)
    audit(db, admin, "users", user.id, "reset_password")
    db.commit()
    return {"status": "password_reset"}


@router.get("/projects", response_model=list[ProjectOut])
def list_projects(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Project]:
    ids = visible_project_ids(db, user)
    query = db.query(Project).order_by(Project.created_at.desc())
    if ids is not None:
        query = query.filter(Project.id.in_(ids))
    return query.all()


@router.post("/projects", response_model=ProjectOut, status_code=201)
def create_project(
    payload: ProjectIn, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> Project:
    project = Project(**payload.model_dump())
    db.add(project)
    db.flush()
    audit(db, admin, "projects", project.id, "create_project", payload.model_dump(mode="json"))
    db.commit()
    db.refresh(project)
    return project


@router.get("/projects/{project_id}", response_model=ProjectOut)
def get_project(project_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Project:
    ensure_project_access(db, user, project_id)
    project = db.get(Project, project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    return project


@router.put("/projects/{project_id}", response_model=ProjectOut)
def update_project(
    project_id: str, payload: ProjectIn, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> Project:
    project = db.get(Project, project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    for key, value in payload.model_dump().items():
        setattr(project, key, value)
    audit(db, admin, "projects", project.id, "update_project", payload.model_dump(mode="json"))
    db.commit()
    db.refresh(project)
    return project


@router.delete("/projects/{project_id}")
def delete_project(
    project_id: str, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> dict[str, str]:
    project = db.get(Project, project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    project.status = "inactive"
    audit(db, admin, "projects", project.id, "archive_project")
    db.commit()
    return {"status": "inactive"}


@router.post("/projects/{project_id}/users")
def attach_project_user(
    project_id: str,
    user_id: str,
    admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    if not db.get(Project, project_id) or not db.get(User, user_id):
        raise HTTPException(status_code=404, detail="Projeto ou usuario nao encontrado")
    exists = db.query(ProjectUser).filter_by(project_id=project_id, user_id=user_id).first()
    if not exists:
        db.add(ProjectUser(project_id=project_id, user_id=user_id))
    audit(db, admin, "projects", project_id, "attach_user", {"user_id": user_id})
    db.commit()
    return {"status": "linked"}


@router.delete("/projects/{project_id}/users/{user_id}")
def detach_project_user(
    project_id: str,
    user_id: str,
    admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    db.query(ProjectUser).filter_by(project_id=project_id, user_id=user_id).delete()
    audit(db, admin, "projects", project_id, "detach_user", {"user_id": user_id})
    db.commit()
    return {"status": "unlinked"}


@router.get("/projects/{project_id}/sections", response_model=list[SectionOut])
def list_sections(project_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Section]:
    ensure_project_access(db, user, project_id)
    return db.query(Section).filter_by(project_id=project_id).order_by(Section.order_index).all()


@router.post("/projects/{project_id}/sections", response_model=SectionOut, status_code=201)
def create_section(
    project_id: str, payload: SectionIn, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> Section:
    if not db.get(Project, project_id):
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    section = Section(project_id=project_id, **payload.model_dump())
    db.add(section)
    db.flush()
    audit(db, admin, "sections", section.id, "create_section", payload.model_dump())
    db.commit()
    db.refresh(section)
    return section


@router.put("/sections/{section_id}", response_model=SectionOut)
def update_section(
    section_id: str, payload: SectionIn, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> Section:
    section = db.get(Section, section_id)
    if not section:
        raise HTTPException(status_code=404, detail="Trecho nao encontrado")
    section.name = payload.name
    section.order_index = payload.order_index
    audit(db, admin, "sections", section.id, "update_section", payload.model_dump())
    db.commit()
    db.refresh(section)
    return section


@router.delete("/sections/{section_id}")
def delete_section(
    section_id: str, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> dict[str, str]:
    section = db.get(Section, section_id)
    if not section:
        raise HTTPException(status_code=404, detail="Trecho nao encontrado")
    db.delete(section)
    audit(db, admin, "sections", section_id, "delete_section")
    db.commit()
    return {"status": "deleted"}


@router.get("/sections/{section_id}/work-points", response_model=list[WorkPointOut])
def list_work_points(
    section_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[WorkPoint]:
    section = db.get(Section, section_id)
    if not section:
        raise HTTPException(status_code=404, detail="Trecho nao encontrado")
    ensure_project_access(db, user, section.project_id)
    return db.query(WorkPoint).filter_by(section_id=section_id).order_by(WorkPoint.order_index).all()


@router.post("/sections/{section_id}/work-points", response_model=WorkPointOut, status_code=201)
def create_work_point(
    section_id: str, payload: WorkPointIn, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> WorkPoint:
    if not db.get(Section, section_id):
        raise HTTPException(status_code=404, detail="Trecho nao encontrado")
    point = WorkPoint(section_id=section_id, **payload.model_dump())
    db.add(point)
    db.flush()
    audit(db, admin, "work_points", point.id, "create_work_point", payload.model_dump())
    db.commit()
    db.refresh(point)
    return point


@router.put("/work-points/{point_id}", response_model=WorkPointOut)
def update_work_point(
    point_id: str, payload: WorkPointIn, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> WorkPoint:
    point = db.get(WorkPoint, point_id)
    if not point:
        raise HTTPException(status_code=404, detail="Ponto nao encontrado")
    for key, value in payload.model_dump().items():
        setattr(point, key, value)
    audit(db, admin, "work_points", point.id, "update_work_point", payload.model_dump())
    db.commit()
    db.refresh(point)
    return point


@router.delete("/work-points/{point_id}")
def delete_work_point(
    point_id: str, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> dict[str, str]:
    point = db.get(WorkPoint, point_id)
    if not point:
        raise HTTPException(status_code=404, detail="Ponto nao encontrado")
    point.is_active = False
    audit(db, admin, "work_points", point.id, "deactivate_work_point")
    db.commit()
    return {"status": "inactive"}


@router.get("/forms", response_model=list[FormOut])
def list_forms(_: User = Depends(require_roles("admin")), db: Session = Depends(get_db)) -> list[Form]:
    return (
        db.query(Form)
        .options(selectinload(Form.fields), selectinload(Form.project_links))
        .order_by(Form.created_at.desc())
        .all()
    )


@router.post("/forms", response_model=FormOut, status_code=201)
def create_form(payload: FormIn, admin: User = Depends(require_roles("admin")), db: Session = Depends(get_db)) -> Form:
    valid_projects = [pid for pid in dict.fromkeys(payload.all_project_ids) if db.get(Project, pid)]
    if not valid_projects:
        raise HTTPException(status_code=422, detail="Informe ao menos um projeto valido para o formulario")
    form = Form(
        project_id=valid_projects[0],
        name=payload.name,
        description=payload.description,
        status=payload.status,
        current_version=1,
    )
    db.add(form)
    db.flush()
    replace_form_projects(db, form, valid_projects)
    for field in payload.fields:
        db.add(FormField(form_id=form.id, version=1, **field.model_dump()))
    audit(db, admin, "forms", form.id, "create_form", payload.model_dump(mode="json"))
    db.commit()
    db.refresh(form)
    return form


@router.get("/forms/{form_id}", response_model=FormOut)
def get_form(
    form_id: str, _: User = Depends(require_roles("admin")), db: Session = Depends(get_db)
) -> Form:
    form = db.query(Form).options(selectinload(Form.fields), selectinload(Form.project_links)).filter_by(id=form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Formulario nao encontrado")
    return form


@router.put("/forms/{form_id}", response_model=FormOut)
def update_form(
    form_id: str, payload: FormIn, admin: User = Depends(require_roles("admin")), db: Session = Depends(get_db)
) -> Form:
    form = db.get(Form, form_id)
    if not form:
        raise HTTPException(status_code=404, detail="Formulario nao encontrado")
    replace_form_projects(db, form, payload.all_project_ids)
    form.name = payload.name
    form.description = payload.description
    form.status = payload.status
    form.current_version += 1
    db.query(FormField).filter_by(form_id=form.id).delete()
    for field in payload.fields:
        db.add(FormField(form_id=form.id, version=form.current_version, **field.model_dump()))
    audit(db, admin, "forms", form.id, "update_form", payload.model_dump(mode="json"))
    db.commit()
    db.refresh(form)
    return form


@router.post("/forms/{form_id}/publish", response_model=FormOut)
def publish_form(form_id: str, admin: User = Depends(require_roles("admin")), db: Session = Depends(get_db)) -> Form:
    form = db.query(Form).options(selectinload(Form.fields), selectinload(Form.project_links)).filter_by(id=form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Formulario nao encontrado")
    form.status = "published"
    snapshot = {
        "name": form.name,
        "description": form.description,
        "version": form.current_version,
        "fields": [
            {
                "label": field.label,
                "field_key": field.field_key,
                "field_type": field.field_type,
                "is_required": field.is_required,
                "order_index": field.order_index,
                "options": field.options,
                "conditional_logic": field.conditional_logic,
            }
            for field in sorted(form.fields, key=lambda item: item.order_index)
        ],
    }
    existing = db.query(FormVersion).filter_by(form_id=form.id, version=form.current_version).first()
    if existing:
        existing.schema_snapshot = snapshot
        existing.status = "published"
    else:
        db.add(FormVersion(form_id=form.id, version=form.current_version, status="published", schema_snapshot=snapshot))
    audit(db, admin, "forms", form.id, "publish_form", {"version": form.current_version})
    db.commit()
    db.refresh(form)
    return form


@router.post("/forms/{form_id}/archive", response_model=FormOut)
def archive_form(form_id: str, admin: User = Depends(require_roles("admin")), db: Session = Depends(get_db)) -> Form:
    form = db.get(Form, form_id)
    if not form:
        raise HTTPException(status_code=404, detail="Formulario nao encontrado")
    form.status = "inactive"
    audit(db, admin, "forms", form.id, "archive_form")
    db.commit()
    db.refresh(form)
    return form


@router.get("/projects/{project_id}/forms", response_model=list[FormOut])
def project_forms(
    project_id: str, _: User = Depends(require_roles("admin")), db: Session = Depends(get_db)
) -> list[Form]:
    return forms_for_projects(
        db.query(Form).options(selectinload(Form.fields), selectinload(Form.project_links)),
        [project_id],
    ).all()


@router.get("/mobile/bootstrap", response_model=MobileBootstrapOut)
def mobile_bootstrap(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> MobileBootstrapOut:
    ids = visible_project_ids(db, user)
    form_ids = visible_form_ids(db, user)
    if ids is None:
        projects = db.query(Project).filter(Project.status == "active").all()
    else:
        projects = db.query(Project).filter(Project.id.in_(ids), Project.status == "active").all()
    project_ids = [project.id for project in projects]
    sections = db.query(Section).filter(Section.project_id.in_(project_ids)).order_by(Section.order_index).all()
    section_ids = [section.id for section in sections]
    work_points = db.query(WorkPoint).filter(WorkPoint.section_id.in_(section_ids), WorkPoint.is_active.is_(True)).all()
    forms = forms_for_projects(
        db.query(Form).options(selectinload(Form.fields), selectinload(Form.project_links)).filter(Form.status == "published"),
        project_ids,
    )
    if form_ids is not None:
        if not form_ids:
            forms = []
        else:
            forms = forms.filter(Form.id.in_(form_ids)).all()
    else:
        forms = forms.all()
    return MobileBootstrapOut(user=user, projects=projects, sections=sections, work_points=work_points, forms=forms)


@router.get("/mobile/projects", response_model=list[ProjectOut])
def mobile_projects(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Project]:
    return list_projects(user, db)


@router.get("/mobile/forms", response_model=list[FormOut])
def mobile_forms(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Form]:
    ids = visible_project_ids(db, user)
    form_ids = visible_form_ids(db, user)
    query = (
        db.query(Form)
        .options(selectinload(Form.fields), selectinload(Form.project_links))
        .filter(Form.status == "published")
    )
    if ids is not None:
        if not ids:
            return []
        query = forms_for_projects(query, ids)
    if form_ids is not None:
        if not form_ids:
            return []
        query = query.filter(Form.id.in_(form_ids))
    return query.all()


@router.post("/mobile/collections", response_model=CollectionOut, status_code=201)
def mobile_collection(
    payload: CollectionIn, user: User = Depends(require_roles(*MOBILE_COLLECTION_WRITER_ROLES)), db: Session = Depends(get_db)
) -> Collection:
    collection = upsert_collection(db, payload, user)
    db.commit()
    return collection_query(db).filter_by(id=collection.id).first()


@router.post("/mobile/collections/{collection_id}/photos")
async def upload_photo(
    collection_id: str,
    photo_type: str,
    file: UploadFile = File(...),
    user: User = Depends(require_roles(*MOBILE_COLLECTION_WRITER_ROLES)),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    collection = db.get(Collection, collection_id)
    if not collection:
        raise HTTPException(status_code=404, detail="Coleta nao encontrada")
    ensure_collection_update_access(user, collection)
    ensure_project_access(db, user, collection.project_id)
    ensure_form_access(db, user, collection.form_id)
    settings = get_settings()
    upload_dir = Path(settings.upload_dir) / collection_id
    upload_dir.mkdir(parents=True, exist_ok=True)
    suffix = Path(file.filename or "foto.jpg").suffix or ".jpg"
    filename = f"{uuid4()}{suffix}"
    file_path = upload_dir / filename
    content = await file.read()
    file_path.write_bytes(content)
    # O sync do mobile ja cria a linha da foto com o caminho do dispositivo.
    # Aqui apenas substituimos por arquivo real no servidor, evitando duplicar.
    photo = (
        db.query(CollectionPhoto)
        .filter_by(collection_id=collection_id, photo_type=photo_type, original_filename=file.filename)
        .first()
    )
    if photo:
        photo.file_path = str(file_path)
        photo.mime_type = file.content_type
        photo.sync_status = "synced"
    else:
        photo = CollectionPhoto(
            collection_id=collection_id,
            photo_type=photo_type,
            file_path=str(file_path),
            original_filename=file.filename,
            mime_type=file.content_type,
            sync_status="synced",
        )
        db.add(photo)
    db.flush()
    audit(db, user, "collection_photos", photo.id, "upload_photo", {"photo_type": photo_type})
    db.commit()
    return {"id": photo.id, "file_path": str(file_path)}


@router.post("/mobile/sync", response_model=MobileSyncOut)
def mobile_sync(
    payload: MobileSyncIn, user: User = Depends(require_roles(*MOBILE_COLLECTION_WRITER_ROLES)), db: Session = Depends(get_db)
) -> MobileSyncOut:
    synced: list[dict[str, str]] = []
    errors: list[dict[str, str]] = []
    for item in payload.collections:
        try:
            collection = upsert_collection(db, item, user, payload.device_id)
            synced.append({"local_uuid": item.local_uuid, "server_uuid": collection.server_uuid or collection.id})
            db.commit()
        except HTTPException as exc:
            db.rollback()
            errors.append({"local_uuid": item.local_uuid, "error": str(exc.detail)})
    return MobileSyncOut(synced=synced, errors=errors)


@router.get("/collections", response_model=list[CollectionOut])
def list_collections(
    project_id: str | None = None,
    form_id: str | None = None,
    section_id: str | None = None,
    work_point_id: str | None = None,
    archaeologist_id: str | None = None,
    date_start: str | None = None,
    date_end: str | None = None,
    status_filter: Annotated[str | None, Query(alias="status")] = None,
    vestigio_identificado: bool | None = None,
    intercorrencia: bool | None = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Collection]:
    ids = visible_project_ids(db, user)
    form_ids = visible_form_ids(db, user)
    query = collection_query(db).order_by(Collection.created_at.desc())
    if ids is not None:
        query = query.filter(Collection.project_id.in_(ids))
    if form_ids is not None:
        if not form_ids:
            return []
        query = query.filter(Collection.form_id.in_(form_ids))
    if project_id:
        ensure_project_access(db, user, project_id)
        query = query.filter(Collection.project_id == project_id)
    if form_id:
        ensure_form_access(db, user, form_id)
        query = query.filter(Collection.form_id == form_id)
    if section_id:
        query = query.filter(Collection.section_id == section_id)
    if work_point_id:
        query = query.filter(Collection.work_point_id == work_point_id)
    if archaeologist_id:
        query = query.filter(Collection.user_id == archaeologist_id)
    if status_filter:
        query = query.filter(Collection.status == status_filter)
    if date_start:
        query = query.filter(Collection.collection_date >= date_start)
    if date_end:
        query = query.filter(Collection.collection_date <= date_end)
    collections = query.limit(500).all()
    if vestigio_identificado is not None:
        collections = [
            item
            for item in collections
            if {answer.field_key: answer.answer_value for answer in item.answers}.get("vestigio_identificado")
            is vestigio_identificado
        ]
    if intercorrencia is not None:
        collections = [
            item
            for item in collections
            if {answer.field_key: answer.answer_value for answer in item.answers}.get("intercorrencia_identificada") is intercorrencia
        ]
    return collections


@router.get("/collections/{collection_id}", response_model=CollectionOut)
def get_collection(collection_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Collection:
    collection = collection_query(db).filter_by(id=collection_id).first()
    if not collection:
        raise HTTPException(status_code=404, detail="Coleta nao encontrada")
    ensure_project_access(db, user, collection.project_id)
    ensure_form_access(db, user, collection.form_id)
    return collection


@router.put("/collections/{collection_id}/review", response_model=CollectionOut)
def review_collection(
    collection_id: str,
    reviewer: User = Depends(require_roles("admin", "coordinator")),
    db: Session = Depends(get_db),
) -> Collection:
    collection = collection_query(db).filter_by(id=collection_id).first()
    if not collection:
        raise HTTPException(status_code=404, detail="Coleta nao encontrada")
    ensure_project_access(db, reviewer, collection.project_id)
    ensure_form_access(db, reviewer, collection.form_id)
    collection.status = "reviewed"
    audit(db, reviewer, "collections", collection.id, "review_collection")
    db.commit()
    db.refresh(collection)
    return collection


@router.delete("/collections/{collection_id}")
def delete_collection(
    collection_id: str, admin: User = Depends(require_roles(*SYSTEM_MANAGER_ROLES)), db: Session = Depends(get_db)
) -> dict[str, str]:
    collection = db.get(Collection, collection_id)
    if not collection:
        raise HTTPException(status_code=404, detail="Coleta nao encontrada")
    db.delete(collection)
    audit(db, admin, "collections", collection_id, "delete_collection")
    db.commit()
    return {"status": "deleted"}


@router.get("/exports/collections.xlsx")
def export_xlsx(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Response:
    ids = visible_project_ids(db, user)
    form_ids = visible_form_ids(db, user)
    query = collection_query(db).order_by(Collection.created_at.desc())
    if ids is not None:
        query = query.filter(Collection.project_id.in_(ids))
    if form_ids is not None:
        query = query.filter(Collection.form_id.in_(form_ids))
    content = build_collections_xlsx(query.limit(5000).all())
    return Response(
        content,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": 'attachment; filename="coletas-arqueologia.xlsx"'},
    )


@router.get("/exports/collections.kmz")
def export_kmz(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Response:
    ids = visible_project_ids(db, user)
    form_ids = visible_form_ids(db, user)
    query = collection_query(db).order_by(Collection.created_at.desc())
    if ids is not None:
        query = query.filter(Collection.project_id.in_(ids))
    if form_ids is not None:
        query = query.filter(Collection.form_id.in_(form_ids))
    content = build_collections_kmz(query.limit(5000).all())
    return Response(
        content,
        media_type="application/vnd.google-earth.kmz",
        headers={"Content-Disposition": 'attachment; filename="coletas-arqueologia.kmz"'},
    )


@router.get("/collections/{collection_id}/pdf")
def export_pdf(collection_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Response:
    collection = collection_query(db).filter_by(id=collection_id).first()
    if not collection:
        raise HTTPException(status_code=404, detail="Coleta nao encontrada")
    ensure_project_access(db, user, collection.project_id)
    ensure_form_access(db, user, collection.form_id)
    content = build_collection_pdf(collection)
    return Response(
        content,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="coleta-{collection.id}.pdf"'},
    )
