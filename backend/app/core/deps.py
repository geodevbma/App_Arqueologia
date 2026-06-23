from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.security import decode_token
from app.db.session import get_db
from app.models.entities import ProjectUser, User


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")
GLOBAL_ACCESS_ROLES = {"admin", "coordinator", "viewer"}


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    payload = decode_token(token)
    user = db.get(User, payload.get("sub"))
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario inativo ou inexistente")
    return user


def role_name(user: User) -> str:
    return user.role.name if user.role else ""


def has_global_access(user: User) -> bool:
    return role_name(user) in GLOBAL_ACCESS_ROLES


def require_roles(*roles: str):
    def guard(user: User = Depends(get_current_user)) -> User:
        if role_name(user) not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissao insuficiente")
        return user

    return guard


def ensure_project_access(db: Session, user: User, project_id: str) -> None:
    if has_global_access(user):
        return
    exists = db.query(ProjectUser).filter_by(project_id=project_id, user_id=user.id).first()
    if not exists:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Projeto nao vinculado ao usuario")
