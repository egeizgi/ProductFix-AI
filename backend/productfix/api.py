from __future__ import annotations

from typing import Any, Callable

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .schemas import AnalysisMode, FixCompletionRequest
from .services.analysis_service import (
    analyze_tenant_products,
    import_and_analyze_csv,
)
from .services.fix_service import get_completed_fixes, set_fix_completion
from .services.product_service import get_tenant_database_path, get_tenant_products

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


@app.post("/analyze")
async def analyze(
    file: UploadFile = File(...),
    tenant_id: str = "demo",
    analysis_mode: AnalysisMode = AnalysisMode.rule_based,
) -> dict[str, Any]:
    content = await file.read()
    return _service_call(
        lambda: import_and_analyze_csv(tenant_id, content, analysis_mode)
    )


@app.post("/tenants/{tenant_id}/products/import-csv")
async def import_csv(
    tenant_id: str,
    file: UploadFile = File(...),
    analysis_mode: AnalysisMode = AnalysisMode.rule_based,
) -> dict[str, Any]:
    content = await file.read()
    return _service_call(
        lambda: import_and_analyze_csv(tenant_id, content, analysis_mode)
    )


@app.get("/tenants/{tenant_id}/products")
def tenant_products(tenant_id: str) -> dict[str, Any]:
    return _service_call(
        lambda: {
            "tenant_id": tenant_id,
            "database": str(get_tenant_database_path(tenant_id)),
            "products": get_tenant_products(tenant_id),
        }
    )


@app.get("/tenants/{tenant_id}/analysis")
def tenant_analysis(
    tenant_id: str,
    analysis_mode: AnalysisMode = AnalysisMode.rule_based,
) -> dict[str, Any]:
    return _service_call(lambda: analyze_tenant_products(tenant_id, analysis_mode))


@app.get("/tenants/{tenant_id}/fixes/completed")
def completed_fixes(tenant_id: str) -> dict[str, Any]:
    return _service_call(
        lambda: {
            "tenant_id": tenant_id,
            "completed_fixes": get_completed_fixes(tenant_id),
        }
    )


@app.post("/tenants/{tenant_id}/fixes/{fix_id}/complete")
def set_fix_completed(
    tenant_id: str,
    fix_id: str,
    request: FixCompletionRequest,
) -> dict[str, Any]:
    return _service_call(lambda: set_fix_completion(tenant_id, fix_id, request))


def _service_call(callback: Callable[[], dict[str, Any]]) -> dict[str, Any]:
    try:
        return callback()
    except ValueError as error:
        status_code = (
            422 if "required when completed is true" in str(error) else 400
        )
        raise HTTPException(status_code=status_code, detail=str(error)) from error
