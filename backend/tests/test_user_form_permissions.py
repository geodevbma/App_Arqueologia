from collections.abc import Generator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.routes import router
from app.db.session import Base, get_db
from app.services.seed import FORM_NAME, seed_initial_data


@pytest.fixture()
def api_client() -> Generator[tuple[TestClient, sessionmaker[Session]], None, None]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session = sessionmaker(
        bind=engine,
        autoflush=False,
        autocommit=False,
        expire_on_commit=False,
    )
    Base.metadata.create_all(bind=engine)

    with testing_session() as db:
        seed_initial_data(db)

    app = FastAPI()
    app.include_router(router)

    def override_get_db() -> Generator[Session, None, None]:
        db = testing_session()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as client:
        yield client, testing_session

    Base.metadata.drop_all(bind=engine)
    engine.dispose()


def login(client: TestClient, email: str, password: str) -> str:
    response = client.post("/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200
    return response.json()["access_token"]


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_user_form_links_are_replaced_exactly_and_survive_seed_restart(
    api_client: tuple[TestClient, sessionmaker[Session]],
) -> None:
    client, testing_session = api_client
    admin_token = login(client, "admin@brandt.local", "Admin123!")
    archaeologist_token = login(client, "arqueologo@brandt.local", "Campo123!")

    users_response = client.get("/users", headers=auth(admin_token))
    assert users_response.status_code == 200
    archaeologist = next(user for user in users_response.json() if user["email"] == "arqueologo@brandt.local")

    forms_response = client.get("/forms", headers=auth(admin_token))
    assert forms_response.status_code == 200
    allowed_form = next(form for form in forms_response.json() if form["name"] == FORM_NAME)
    allowed_form_ids = [allowed_form["id"]]

    update_response = client.put(
        f"/users/{archaeologist['id']}",
        headers=auth(admin_token),
        json={"form_ids": allowed_form_ids},
    )
    assert update_response.status_code == 200
    assert update_response.json()["form_ids"] == allowed_form_ids

    user_response = client.get(f"/users/{archaeologist['id']}", headers=auth(admin_token))
    assert user_response.status_code == 200
    assert user_response.json()["form_ids"] == allowed_form_ids

    me_response = client.get("/auth/me", headers=auth(archaeologist_token))
    assert me_response.status_code == 200
    assert me_response.json()["form_ids"] == allowed_form_ids

    bootstrap_response = client.get("/mobile/bootstrap", headers=auth(archaeologist_token))
    assert bootstrap_response.status_code == 200
    assert [form["id"] for form in bootstrap_response.json()["forms"]] == allowed_form_ids

    with testing_session() as db:
        seed_initial_data(db)

    user_after_seed = client.get(f"/users/{archaeologist['id']}", headers=auth(admin_token))
    assert user_after_seed.status_code == 200
    assert user_after_seed.json()["form_ids"] == allowed_form_ids

    bootstrap_after_seed = client.get("/mobile/bootstrap", headers=auth(archaeologist_token))
    assert bootstrap_after_seed.status_code == 200
    assert [form["id"] for form in bootstrap_after_seed.json()["forms"]] == allowed_form_ids

    clear_response = client.put(
        f"/users/{archaeologist['id']}",
        headers=auth(admin_token),
        json={"form_ids": []},
    )
    assert clear_response.status_code == 200
    assert clear_response.json()["form_ids"] == []

    cleared_user = client.get(f"/users/{archaeologist['id']}", headers=auth(admin_token))
    assert cleared_user.status_code == 200
    assert cleared_user.json()["form_ids"] == []

    cleared_bootstrap = client.get("/mobile/bootstrap", headers=auth(archaeologist_token))
    assert cleared_bootstrap.status_code == 200
    assert cleared_bootstrap.json()["forms"] == []
