from __future__ import annotations

import csv
from io import StringIO
from typing import Any

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from .analysis import analyze_products
from .storage import (
    complete_fix,
    list_completed_fixes,
    list_products,
    reopen_fix,
    tenant_db_path,
    upsert_products,
)

app = FastAPI(title="ProductFix AI API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


class FixCompletionRequest(BaseModel):
    sku: str = ""
    title: str = ""
    detail: str = ""
    completed: bool = True


@app.post("/analyze")
async def analyze(file: UploadFile = File(...), tenant_id: str = "demo") -> dict:
    content = (await file.read()).decode("utf-8-sig")
    rows = list(csv.DictReader(StringIO(content)))
    return _persist_and_analyze(tenant_id, rows)


@app.post("/tenants/{tenant_id}/products/import-csv")
async def import_csv(tenant_id: str, file: UploadFile = File(...)) -> dict[str, Any]:
    content = (await file.read()).decode("utf-8-sig")
    rows = list(csv.DictReader(StringIO(content)))
    return _persist_and_analyze(tenant_id, rows)


@app.get("/tenants/{tenant_id}/products")
def tenant_products(tenant_id: str) -> dict[str, Any]:
    return {
        "tenant_id": tenant_id,
        "database": str(_safe_tenant_db_path(tenant_id)),
        "products": _safe_list_products(tenant_id),
    }


@app.get("/tenants/{tenant_id}/analysis")
def tenant_analysis(tenant_id: str) -> dict[str, Any]:
    products = _safe_list_products(tenant_id)
    payload = analyze_products(products)
    return _with_persistence_metadata(tenant_id, payload)


@app.get("/tenants/{tenant_id}/fixes/completed")
def completed_fixes(tenant_id: str) -> dict[str, Any]:
    return {
        "tenant_id": tenant_id,
        "completed_fixes": _safe_completed_fixes(tenant_id),
    }


@app.post("/tenants/{tenant_id}/fixes/{fix_id}/complete")
def set_fix_completed(
    tenant_id: str,
    fix_id: str,
    request: FixCompletionRequest,
) -> dict[str, Any]:
    try:
        if request.completed:
            if not request.sku.strip() or not request.title.strip():
                raise HTTPException(
                    status_code=422,
                    detail="sku and title are required when completed is true",
                )
            result = complete_fix(
                tenant_id,
                fix_id,
                sku=request.sku,
                title=request.title,
                detail=request.detail,
            )
        else:
            result = reopen_fix(
                tenant_id,
                fix_id,
                sku=request.sku,
                title=request.title,
            )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    return {"tenant_id": tenant_id, **result}


def _persist_and_analyze(tenant_id: str, rows: list[dict[str, Any]]) -> dict[str, Any]:
    try:
        imported = upsert_products(tenant_id, rows)
        products = list_products(tenant_id)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    payload = analyze_products(products)
    payload["imported_products"] = imported
    return _with_persistence_metadata(tenant_id, payload)


def _with_persistence_metadata(tenant_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    completed = _safe_completed_fixes(tenant_id)
    completed_ids = {fix["fix_id"] for fix in completed}
    open_actions = [
        action
        for action in payload.get("fix_center", [])
        if action.get("id") not in completed_ids
    ]

    return {
        "tenant_id": tenant_id,
        "database": str(_safe_tenant_db_path(tenant_id)),
        "completed_fixes": completed,
        **payload,
        "fix_center": open_actions,
    }


def _safe_list_products(tenant_id: str) -> list[dict[str, Any]]:
    try:
        return list_products(tenant_id)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


def _safe_completed_fixes(tenant_id: str) -> list[dict[str, Any]]:
    try:
        return list_completed_fixes(tenant_id)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


def _safe_tenant_db_path(tenant_id: str) -> Any:
    try:
        return tenant_db_path(tenant_id)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
