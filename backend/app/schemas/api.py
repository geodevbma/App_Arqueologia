from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class LoginIn(BaseModel):
    email: str
    password: str


class RoleOut(ORMModel):
    id: str
    name: str
    description: str | None = None


class UserOut(ORMModel):
    id: str
    name: str
    email: str
    role: RoleOut
    is_active: bool
    project_ids: list[str] = []
    form_ids: list[str] = []
    created_at: datetime
    updated_at: datetime


class UserCreate(BaseModel):
    name: str
    email: str
    password: str = Field(min_length=8)
    role_id: str | None = None
    role: str | None = None
    is_active: bool = True
    project_ids: list[str] = []
    form_ids: list[str] = []


class UserUpdate(BaseModel):
    name: str | None = None
    email: str | None = None
    password: str | None = Field(default=None, min_length=8)
    role_id: str | None = None
    role: str | None = None
    is_active: bool | None = None
    project_ids: list[str] | None = None
    form_ids: list[str] | None = None


class ProjectIn(BaseModel):
    name: str
    code: str | None = None
    description: str | None = None
    status: str = "active"
    start_date: date | None = None
    end_date: date | None = None


class ProjectOut(ORMModel):
    id: str
    name: str
    code: str | None
    description: str | None
    status: str
    start_date: date | None
    end_date: date | None
    created_at: datetime
    updated_at: datetime


class SectionIn(BaseModel):
    name: str
    order_index: int = 0


class SectionOut(ORMModel):
    id: str
    project_id: str
    name: str
    order_index: int


class WorkPointIn(BaseModel):
    name: str
    order_index: int = 0
    is_active: bool = True


class WorkPointOut(ORMModel):
    id: str
    section_id: str
    name: str
    order_index: int
    is_active: bool


class FormFieldIn(BaseModel):
    label: str
    field_key: str
    field_type: str
    is_required: bool = False
    order_index: int = 0
    options: Any | None = None
    conditional_logic: Any | None = None


class FormIn(BaseModel):
    project_id: str
    name: str
    description: str | None = None
    status: Literal["draft", "published", "inactive"] = "draft"
    fields: list[FormFieldIn] = []


class FormFieldOut(ORMModel):
    id: str
    form_id: str
    version: int
    label: str
    field_key: str
    field_type: str
    is_required: bool
    order_index: int
    options: Any | None
    conditional_logic: Any | None


class FormOut(ORMModel):
    id: str
    project_id: str
    name: str
    description: str | None
    status: str
    current_version: int
    fields: list[FormFieldOut] = []
    created_at: datetime
    updated_at: datetime


class CollectionAnswerIn(BaseModel):
    field_id: str | None = None
    field_key: str
    answer_value: Any | None = None


class CollectionPhotoIn(BaseModel):
    field_id: str | None = None
    photo_type: str
    file_path: str
    original_filename: str | None = None
    mime_type: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    taken_at: datetime | None = None
    metadata: Any | None = None
    sync_status: str = "pending_sync"


class CollectionIn(BaseModel):
    local_uuid: str
    project_id: str
    form_id: str
    form_version: int = 1
    section_id: str | None = None
    work_point_id: str | None = None
    work_point_other: str | None = None
    user_id: str | None = None
    collection_date: date | None = None
    latitude: float | None = None
    longitude: float | None = None
    gps_accuracy: float | None = None
    original_latitude: float | None = None
    original_longitude: float | None = None
    coordinate_was_edited: bool = False
    status: str = "pending_sync"
    sync_status: str = "pending_sync"
    created_locally_at: datetime | None = None
    updated_locally_at: datetime | None = None
    answers: list[CollectionAnswerIn] = []
    photos: list[CollectionPhotoIn] = []


class CollectionAnswerOut(ORMModel):
    id: str
    field_id: str | None
    field_key: str
    answer_value: Any | None


class CollectionPhotoOut(ORMModel):
    id: str
    field_id: str | None
    photo_type: str
    file_path: str
    original_filename: str | None
    mime_type: str | None
    latitude: float | None
    longitude: float | None
    taken_at: datetime | None
    sync_status: str


class CollectionOut(ORMModel):
    id: str
    local_uuid: str
    server_uuid: str | None
    project_id: str
    form_id: str
    form_version: int
    section_id: str | None
    work_point_id: str | None
    work_point_other: str | None
    user_id: str
    collection_date: date | None
    latitude: float | None
    longitude: float | None
    gps_accuracy: float | None
    original_latitude: float | None
    original_longitude: float | None
    coordinate_was_edited: bool
    status: str
    sync_status: str
    created_locally_at: datetime | None
    updated_locally_at: datetime | None
    synced_at: datetime | None
    answers: list[CollectionAnswerOut] = []
    photos: list[CollectionPhotoOut] = []
    created_at: datetime
    updated_at: datetime


class MobileBootstrapOut(BaseModel):
    user: UserOut
    projects: list[ProjectOut]
    sections: list[SectionOut]
    work_points: list[WorkPointOut]
    forms: list[FormOut]


class MobileSyncIn(BaseModel):
    device_id: str | None = None
    collections: list[CollectionIn]


class MobileSyncOut(BaseModel):
    synced: list[dict[str, str]]
    errors: list[dict[str, str]]
