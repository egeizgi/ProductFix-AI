from __future__ import annotations

from typing import Any

from productfix.schemas import FixCompletionRequest
from productfix.storage import complete_fix, list_completed_fixes, reopen_fix


def get_completed_fixes(tenant_id: str) -> list[dict[str, Any]]:
    return list_completed_fixes(tenant_id)


def set_fix_completion(
    tenant_id: str,
    fix_id: str,
    request: FixCompletionRequest,
) -> dict[str, Any]:
    if request.completed:
        if not request.sku.strip() or not request.title.strip():
            raise ValueError("sku and title are required when completed is true")
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

    return {"tenant_id": tenant_id, **result}
