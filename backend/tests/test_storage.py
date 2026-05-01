from __future__ import annotations

from typing import Callable

from productfix.storage import (
    complete_fix,
    list_completed_fixes,
    list_products,
    reopen_fix,
    tenant_db_path,
    upsert_products,
)


def test_upsert_products_persists_rows_per_tenant(
    tenant_id_factory: Callable[[str], str],
) -> None:
    tenant_id = tenant_id_factory()

    imported = upsert_products(
        tenant_id,
        [
            {
                "sku": "SKU-1",
                "name": "First Name",
                "category": "giyim",
                "views": "100",
                "add_to_cart": "10",
                "purchases": "4",
                "returns": "1",
                "description": "desc",
                "reviews": "",
                "return_reasons": "",
                "photo_count": "2",
                "has_size_chart": "false",
                "has_model_photo": "true",
            }
        ],
    )

    assert imported == 1
    assert tenant_db_path(tenant_id).exists()
    assert list_products(tenant_id)[0]["name"] == "First Name"

    upsert_products(
        tenant_id,
        [
            {
                "sku": "SKU-1",
                "name": "Updated Name",
                "category": "giyim",
                "views": "150",
                "add_to_cart": "20",
                "purchases": "8",
                "returns": "1",
                "description": "updated",
                "reviews": "",
                "return_reasons": "",
                "photo_count": "4",
                "has_size_chart": "true",
                "has_model_photo": "true",
            }
        ],
    )

    products = list_products(tenant_id)
    assert len(products) == 1
    assert products[0]["name"] == "Updated Name"
    assert products[0]["has_size_chart"] is True


def test_completed_fixes_can_be_reopened_by_matching_title(
    tenant_id_factory: Callable[[str], str],
) -> None:
    tenant_id = tenant_id_factory()

    complete_fix(
        tenant_id,
        "old-hash-id",
        sku="DRS-220",
        title="Beden veya kalip bilgisini fiyatın hemen altına taşı.",
        detail="old detail",
    )

    completed = list_completed_fixes(tenant_id)
    assert len(completed) == 1
    assert completed[0]["match_key"] == "DRS-220:beden-veya-kalip-bilgisini-fiyatin-hemen-altina-tasi"

    reopen_fix(
        tenant_id,
        "new-stable-id",
        sku="DRS-220",
        title="Beden veya kalıp bilgisini fiyatın hemen altına taşı.",
    )

    assert list_completed_fixes(tenant_id) == []
