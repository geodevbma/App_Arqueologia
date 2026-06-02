from datetime import date

from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.entities import Form, FormField, FormVersion, Project, ProjectUser, Role, Section, User, UserForm, WorkPoint


PROJECT_NAME = "Projeto de Acompanhamento Arqueologico Ramal Turistico Ouro Preto - Mariana"
FORM_NAME = "Formulario de Acompanhamento Arqueologico"

SECTIONS = {
    "Trecho 01": ["000+800", "001+850", "002+300", "003+925", "006+800"],
    "Trecho 02": ["008+615", "009+225", "010+300", "012+255", "012+465", "015+450+60", "015+855"],
    "Trecho 03": ["016+145", "016+900"],
}

INITIAL_FIELDS = [
    {
        "label": "Projeto",
        "field_key": "project_id",
        "field_type": "select",
        "is_required": True,
        "order_index": 1,
        "options": {"source": "projects"},
    },
    {
        "label": "Trecho",
        "field_key": "section_id",
        "field_type": "select",
        "is_required": True,
        "order_index": 2,
        "options": {"source": "sections", "depends_on": "project_id"},
    },
    {
        "label": "Obra/Ponto",
        "field_key": "work_point_id",
        "field_type": "select",
        "is_required": True,
        "order_index": 3,
        "options": {"source": "work_points", "depends_on": "section_id", "include_other": True},
    },
    {
        "label": "Outro - Qual?",
        "field_key": "work_point_other",
        "field_type": "text",
        "is_required": True,
        "order_index": 4,
        "conditional_logic": {"field": "work_point_id", "operator": "equals", "value": "other"},
    },
    {"label": "Data", "field_key": "collection_date", "field_type": "date", "is_required": True, "order_index": 5},
    {
        "label": "Nome do Arqueologo",
        "field_key": "archaeologist_name",
        "field_type": "auto_user",
        "is_required": True,
        "order_index": 6,
    },
    {
        "label": "Ponto georreferenciado",
        "field_key": "coordinates",
        "field_type": "coordinate",
        "is_required": True,
        "order_index": 7,
    },
    {
        "label": "Foto da atividade",
        "field_key": "activity_photo",
        "field_type": "photo",
        "is_required": True,
        "order_index": 8,
    },
    {
        "label": "Foto da paisagem",
        "field_key": "landscape_photo",
        "field_type": "photo",
        "is_required": True,
        "order_index": 9,
    },
    {
        "label": "Descricao da atividade",
        "field_key": "activity_description",
        "field_type": "textarea",
        "is_required": True,
        "order_index": 10,
    },
    {
        "label": "Foi identificado algum vestigio arqueologico?",
        "field_key": "vestigio_identificado",
        "field_type": "boolean",
        "is_required": True,
        "order_index": 11,
    },
    {
        "label": "Qual vestigio?",
        "field_key": "qual_vestigio",
        "field_type": "text",
        "is_required": True,
        "order_index": 12,
        "conditional_logic": {"field": "vestigio_identificado", "operator": "equals", "value": True},
    },
    {
        "label": "Houve alguma intercorrencia durante as atividades?",
        "field_key": "intercorrencia_identificada",
        "field_type": "boolean",
        "is_required": True,
        "order_index": 13,
    },
    {
        "label": "Qual intercorrencia?",
        "field_key": "qual_intercorrencia",
        "field_type": "text",
        "is_required": True,
        "order_index": 14,
        "conditional_logic": {"field": "intercorrencia_identificada", "operator": "equals", "value": True},
    },
]


def seed_initial_data(db: Session) -> None:
    role_descriptions = {
        "admin": "Administrador com acesso completo ao sistema.",
        "coordinator": "Coordenador de projetos, revisao e exportacao.",
        "archaeologist": "Arqueologo de campo com coleta offline.",
        "viewer": "Visualizador com acesso de consulta.",
    }
    roles: dict[str, Role] = {}
    for name, description in role_descriptions.items():
        role = db.query(Role).filter_by(name=name).first()
        if not role:
            role = Role(name=name, description=description)
            db.add(role)
            db.flush()
        roles[name] = role

    project = db.query(Project).filter_by(name=PROJECT_NAME).first()
    if not project:
        project = Project(
            name=PROJECT_NAME,
            code="OPM-001",
            description="Acompanhamento arqueologico do Ramal Turistico Ouro Preto - Mariana.",
            status="active",
            start_date=date.today(),
        )
        db.add(project)
        db.flush()

    for section_index, (section_name, points) in enumerate(SECTIONS.items(), start=1):
        section = db.query(Section).filter_by(project_id=project.id, name=section_name).first()
        if not section:
            section = Section(project_id=project.id, name=section_name, order_index=section_index)
            db.add(section)
            db.flush()
        for point_index, point_name in enumerate(points, start=1):
            exists = db.query(WorkPoint).filter_by(section_id=section.id, name=point_name).first()
            if not exists:
                db.add(WorkPoint(section_id=section.id, name=point_name, order_index=point_index, is_active=True))

    users = [
        ("Administrador Brandt", "admin@brandt.local", "Admin123!", "admin"),
        ("Coordenador Arqueologia", "coordenador@brandt.local", "Coord123!", "coordinator"),
        ("Arqueologa de Campo", "arqueologo@brandt.local", "Campo123!", "archaeologist"),
        ("Visualizador Brandt", "viewer@brandt.local", "Viewer123!", "viewer"),
    ]
    seeded_users: list[User] = []
    for name, email, password, role_name in users:
        user = db.query(User).filter_by(email=email).first()
        if not user:
            user = User(name=name, email=email, password_hash=hash_password(password), role_id=roles[role_name].id)
            db.add(user)
            db.flush()
        seeded_users.append(user)
        linked = db.query(ProjectUser).filter_by(project_id=project.id, user_id=user.id).first()
        if not linked:
            db.add(ProjectUser(project_id=project.id, user_id=user.id))

    form = db.query(Form).filter_by(project_id=project.id, name=FORM_NAME).first()
    if not form:
        form = Form(
            project_id=project.id,
            name=FORM_NAME,
            description="Ficha principal para acompanhamento arqueologico em campo.",
            status="published",
            current_version=1,
        )
        db.add(form)
        db.flush()
        for field in INITIAL_FIELDS:
            db.add(FormField(form_id=form.id, version=1, **field))
        db.add(
            FormVersion(
                form_id=form.id,
                version=1,
                status="published",
                schema_snapshot={"name": FORM_NAME, "fields": INITIAL_FIELDS},
            )
        )

    for user in seeded_users:
        linked_form = db.query(UserForm).filter_by(user_id=user.id, form_id=form.id).first()
        if not linked_form:
            db.add(UserForm(user_id=user.id, form_id=form.id))

    db.commit()
