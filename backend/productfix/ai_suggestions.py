from __future__ import annotations

from typing import Any


def generate_ai_fix(product: dict[str, Any]) -> dict[str, str]:
    """
    Later this function can call an LLM.
    For now it returns a structured suggestion.
    """
    return {
        "improved_title": str(product["name"]),
        "improved_description": str(product["suggested_description"]),
        "warning_badge": str(product["buyer_warning"]),
    }


def attach_ai_suggestions(analysis_payload: dict[str, Any]) -> dict[str, Any]:
    products = [
        {
            **product,
            "ai_fix": generate_ai_fix(product),
        }
        for product in analysis_payload.get("products", [])
    ]

    return {
        **analysis_payload,
        "analysis_mode": "llm_powered",
        "ai_provider": "stub",
        "products": products,
    }
