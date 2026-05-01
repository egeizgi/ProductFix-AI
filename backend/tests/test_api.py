from __future__ import annotations

from pathlib import Path
from uuid import uuid4

from fastapi.testclient import TestClient

from productfix.api import app


def _tenant_id() -> str:
    return f"api-{uuid4().hex[:12]}"


def test_health_endpoint() -> None:
    client = TestClient(app)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_import_csv_and_llm_powered_analysis() -> None:
    client = TestClient(app)
    tenant_id = _tenant_id()
    sample_csv = Path("data/sample-products.csv").read_bytes()

    response = client.post(
        f"/tenants/{tenant_id}/products/import-csv?analysis_mode=llm_powered",
        files={"file": ("sample-products.csv", sample_csv, "text/csv")},
    )

    body = response.json()
    assert response.status_code == 200
    assert body["tenant_id"] == tenant_id
    assert body["analysis_mode"] == "llm_powered"
    assert body["ai_provider"] == "stub"
    assert body["imported_products"] == 5
    assert "ai_fix" in body["products"][0]


def test_completed_fix_is_hidden_from_open_fix_center() -> None:
    client = TestClient(app)
    tenant_id = _tenant_id()
    sample_csv = Path("data/sample-products.csv").read_bytes()

    import_response = client.post(
        f"/tenants/{tenant_id}/products/import-csv",
        files={"file": ("sample-products.csv", sample_csv, "text/csv")},
    )
    first_action = import_response.json()["fix_center"][0]

    complete_response = client.post(
        f"/tenants/{tenant_id}/fixes/{first_action['id']}/complete",
        json={
            "sku": first_action["sku"],
            "title": first_action["title"],
            "detail": first_action["detail"],
        },
    )
    analysis_response = client.get(f"/tenants/{tenant_id}/analysis")
    open_ids = {action["id"] for action in analysis_response.json()["fix_center"]}

    assert complete_response.status_code == 200
    assert complete_response.json()["completed"] is True
    assert first_action["id"] not in open_ids
