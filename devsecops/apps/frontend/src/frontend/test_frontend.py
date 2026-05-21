import pytest
from unittest.mock import patch, MagicMock

from frontend import app, create_user, backend_status


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_healthz_backend_ok(client):
    with patch("frontend.requests.get") as mock_get:
        mock_get.return_value.status_code = 200
        resp = client.get("/healthz")
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["frontend_status"] == "ok"
        assert data["backend_status"] == "ok"


def test_healthz_backend_down(client):
    with patch("frontend.requests.get", side_effect=Exception("refused")):
        resp = client.get("/healthz")
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["backend_status"] == "nok"


def test_index_get(client):
    resp = client.get("/")
    assert resp.status_code == 200


def test_index_post_success(client):
    with patch("frontend.requests.post") as mock_post:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {"id": 1, "name": "Alice"}
        mock_post.return_value = mock_resp
        resp = client.post("/", data={"id": "1", "name": "Alice"})
        assert resp.status_code == 200


def test_index_post_backend_error(client):
    with patch("frontend.requests.post") as mock_post:
        mock_resp = MagicMock()
        mock_resp.status_code = 500
        mock_post.return_value = mock_resp
        resp = client.post("/", data={"id": "1", "name": "Alice"})
        assert resp.status_code == 200


def test_create_user_ok():
    with patch("frontend.requests.post") as mock_post:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {"id": 1, "name": "Alice"}
        mock_post.return_value = mock_resp
        status, response = create_user("1", "Alice")
        assert status == 200
        assert response == {"id": 1, "name": "Alice"}


def test_create_user_non_200():
    with patch("frontend.requests.post") as mock_post:
        mock_resp = MagicMock()
        mock_resp.status_code = 409
        mock_post.return_value = mock_resp
        status, response = create_user("1", "Alice")
        assert status == 409
        assert response is None


def test_create_user_exception():
    with patch("frontend.requests.post", side_effect=Exception("timeout")):
        result = create_user("1", "Alice")
        assert result is None


def test_backend_status_ok():
    with patch("frontend.requests.get") as mock_get:
        mock_get.return_value.status_code = 200
        assert backend_status() == "ok"


def test_backend_status_down():
    with patch("frontend.requests.get", side_effect=Exception("refused")):
        assert backend_status() == "nok"
