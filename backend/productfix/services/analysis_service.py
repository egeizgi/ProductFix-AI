from __future__ import annotations

from typing import Any

from productfix.ai_suggestions import attach_ai_suggestions
from productfix.analysis import analyze_products
from productfix.schemas import AnalysisMode
from productfix.services.fix_service import get_completed_fixes
from productfix.services.product_service import (
    get_tenant_database_path,
    get_tenant_products,
    import_products_from_csv,
)


def analyze_with_mode(
    products: list[dict[str, Any]],
    analysis_mode: AnalysisMode,
) -> dict[str, Any]:
    payload = analyze_products(products)
    if analysis_mode == AnalysisMode.llm_powered:
        return attach_ai_suggestions(payload)
    return {"analysis_mode": AnalysisMode.rule_based.value, **payload}


def analyze_tenant_products(
    tenant_id: str,
    analysis_mode: AnalysisMode,
) -> dict[str, Any]:
    payload = analyze_with_mode(get_tenant_products(tenant_id), analysis_mode)
    return add_tenant_metadata(tenant_id, payload)


def import_and_analyze_csv(
    tenant_id: str,
    content: bytes,
    analysis_mode: AnalysisMode,
) -> dict[str, Any]:
    imported = import_products_from_csv(tenant_id, content)
    payload = analyze_with_mode(imported["products"], analysis_mode)
    payload["imported_products"] = imported["imported_products"]
    return add_tenant_metadata(tenant_id, payload)


def add_tenant_metadata(tenant_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    completed = get_completed_fixes(tenant_id)
    completed_ids = {fix["fix_id"] for fix in completed}
    open_actions = [
        action
        for action in payload.get("fix_center", [])
        if action.get("id") not in completed_ids
    ]

    return {
        "tenant_id": tenant_id,
        "database": str(get_tenant_database_path(tenant_id)),
        "completed_fixes": completed,
        **payload,
        "fix_center": open_actions,
    }
