from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import JSON

from app.db.session import Base


def new_id() -> str:
    return str(uuid4())


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )


class Role(Base):
    __tablename__ = "roles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)

    users: Mapped[list["User"]] = relationship(back_populates="role")


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role_id: Mapped[str] = mapped_column(ForeignKey("roles.id"), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    role: Mapped[Role] = relationship(back_populates="users")
    project_links: Mapped[list["ProjectUser"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    form_links: Mapped[list["UserForm"]] = relationship(back_populates="user", cascade="all, delete-orphan")

    @property
    def project_ids(self) -> list[str]:
        return [link.project_id for link in self.project_links]

    @property
    def form_ids(self) -> list[str]:
        return [link.form_id for link in self.form_links]


class Project(Base, TimestampMixin):
    __tablename__ = "projects"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    code: Mapped[str | None] = mapped_column(String(80))
    description: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(30), default="active", index=True)
    start_date = mapped_column(Date, nullable=True)
    end_date = mapped_column(Date, nullable=True)

    sections: Mapped[list["Section"]] = relationship(back_populates="project", cascade="all, delete-orphan")
    forms: Mapped[list["Form"]] = relationship(back_populates="project", cascade="all, delete-orphan")
    user_links: Mapped[list["ProjectUser"]] = relationship(back_populates="project", cascade="all, delete-orphan")


class ProjectUser(Base):
    __tablename__ = "project_users"
    __table_args__ = (UniqueConstraint("project_id", "user_id", name="uq_project_user"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    project_id: Mapped[str] = mapped_column(ForeignKey("projects.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    project: Mapped[Project] = relationship(back_populates="user_links")
    user: Mapped[User] = relationship(back_populates="project_links")


class UserForm(Base):
    __tablename__ = "user_forms"
    __table_args__ = (UniqueConstraint("user_id", "form_id", name="uq_user_form"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    form_id: Mapped[str] = mapped_column(ForeignKey("forms.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    user: Mapped[User] = relationship(back_populates="form_links")
    form: Mapped["Form"] = relationship()


class Section(Base, TimestampMixin):
    __tablename__ = "sections"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    project_id: Mapped[str] = mapped_column(ForeignKey("projects.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, default=0)

    project: Mapped[Project] = relationship(back_populates="sections")
    work_points: Mapped[list["WorkPoint"]] = relationship(back_populates="section", cascade="all, delete-orphan")


class WorkPoint(Base, TimestampMixin):
    __tablename__ = "work_points"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    section_id: Mapped[str] = mapped_column(ForeignKey("sections.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    section: Mapped[Section] = relationship(back_populates="work_points")


class Form(Base, TimestampMixin):
    __tablename__ = "forms"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    project_id: Mapped[str] = mapped_column(ForeignKey("projects.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(30), default="draft", index=True)
    current_version: Mapped[int] = mapped_column(Integer, default=1)

    project: Mapped[Project] = relationship(back_populates="forms")
    fields: Mapped[list["FormField"]] = relationship(back_populates="form", cascade="all, delete-orphan")
    versions: Mapped[list["FormVersion"]] = relationship(back_populates="form", cascade="all, delete-orphan")


class FormVersion(Base, TimestampMixin):
    __tablename__ = "form_versions"
    __table_args__ = (UniqueConstraint("form_id", "version", name="uq_form_version"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    form_id: Mapped[str] = mapped_column(ForeignKey("forms.id"), nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    schema_snapshot = mapped_column(JSON, nullable=False, default=dict)
    status: Mapped[str] = mapped_column(String(30), default="draft")

    form: Mapped[Form] = relationship(back_populates="versions")


class FormField(Base, TimestampMixin):
    __tablename__ = "form_fields"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    form_id: Mapped[str] = mapped_column(ForeignKey("forms.id"), nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    label: Mapped[str] = mapped_column(String(255), nullable=False)
    field_key: Mapped[str] = mapped_column(String(120), nullable=False)
    field_type: Mapped[str] = mapped_column(String(50), nullable=False)
    is_required: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    options = mapped_column(JSON, nullable=True)
    conditional_logic = mapped_column(JSON, nullable=True)

    form: Mapped[Form] = relationship(back_populates="fields")


class Collection(Base, TimestampMixin):
    __tablename__ = "collections"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    local_uuid: Mapped[str] = mapped_column(String(36), unique=True, index=True, nullable=False)
    server_uuid: Mapped[str | None] = mapped_column(String(36), unique=True, nullable=True)
    project_id: Mapped[str] = mapped_column(ForeignKey("projects.id"), nullable=False)
    form_id: Mapped[str] = mapped_column(ForeignKey("forms.id"), nullable=False)
    form_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    section_id: Mapped[str | None] = mapped_column(ForeignKey("sections.id"), nullable=True)
    work_point_id: Mapped[str | None] = mapped_column(ForeignKey("work_points.id"), nullable=True)
    work_point_other: Mapped[str | None] = mapped_column(String(160), nullable=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    collection_date = mapped_column(Date, nullable=True)
    latitude = mapped_column(Numeric(10, 7), nullable=True)
    longitude = mapped_column(Numeric(10, 7), nullable=True)
    gps_accuracy = mapped_column(Numeric(10, 2), nullable=True)
    original_latitude = mapped_column(Numeric(10, 7), nullable=True)
    original_longitude = mapped_column(Numeric(10, 7), nullable=True)
    coordinate_was_edited: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="pending_sync", index=True)
    sync_status: Mapped[str] = mapped_column(String(30), default="pending_sync", index=True)
    created_locally_at = mapped_column(DateTime, nullable=True)
    updated_locally_at = mapped_column(DateTime, nullable=True)
    synced_at = mapped_column(DateTime, nullable=True)

    project: Mapped[Project] = relationship()
    form: Mapped[Form] = relationship()
    section: Mapped[Section | None] = relationship()
    work_point: Mapped[WorkPoint | None] = relationship()
    user: Mapped[User] = relationship()
    answers: Mapped[list["CollectionAnswer"]] = relationship(back_populates="collection", cascade="all, delete-orphan")
    photos: Mapped[list["CollectionPhoto"]] = relationship(back_populates="collection", cascade="all, delete-orphan")


class CollectionAnswer(Base, TimestampMixin):
    __tablename__ = "collection_answers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    collection_id: Mapped[str] = mapped_column(ForeignKey("collections.id"), nullable=False)
    field_id: Mapped[str | None] = mapped_column(ForeignKey("form_fields.id"), nullable=True)
    field_key: Mapped[str] = mapped_column(String(120), nullable=False)
    answer_value = mapped_column(JSON, nullable=True)

    collection: Mapped[Collection] = relationship(back_populates="answers")
    field: Mapped[FormField | None] = relationship()


class CollectionPhoto(Base, TimestampMixin):
    __tablename__ = "collection_photos"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    collection_id: Mapped[str] = mapped_column(ForeignKey("collections.id"), nullable=False)
    field_id: Mapped[str | None] = mapped_column(ForeignKey("form_fields.id"), nullable=True)
    photo_type: Mapped[str] = mapped_column(String(80), nullable=False)
    file_path: Mapped[str] = mapped_column(Text, nullable=False)
    original_filename: Mapped[str | None] = mapped_column(String(255))
    mime_type: Mapped[str | None] = mapped_column(String(120))
    latitude = mapped_column(Numeric(10, 7), nullable=True)
    longitude = mapped_column(Numeric(10, 7), nullable=True)
    taken_at = mapped_column(DateTime, nullable=True)
    photo_metadata = mapped_column("metadata", JSON, nullable=True)
    sync_status: Mapped[str] = mapped_column(String(30), default="pending_sync")

    collection: Mapped[Collection] = relationship(back_populates="photos")
    field: Mapped[FormField | None] = relationship()


class SyncLog(Base):
    __tablename__ = "sync_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    collection_id: Mapped[str | None] = mapped_column(ForeignKey("collections.id"), nullable=True)
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    device_id: Mapped[str | None] = mapped_column(String(160))
    action: Mapped[str] = mapped_column(String(80), nullable=False)
    status: Mapped[str] = mapped_column(String(30), nullable=False)
    message: Mapped[str | None] = mapped_column(Text)
    payload = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    entity_name: Mapped[str] = mapped_column(String(120), nullable=False)
    entity_id: Mapped[str] = mapped_column(String(36), nullable=False)
    action: Mapped[str] = mapped_column(String(80), nullable=False)
    old_value = mapped_column(JSON, nullable=True)
    new_value = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
