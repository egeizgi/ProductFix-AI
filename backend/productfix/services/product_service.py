from __future__ import annotations

import csv
from io import StringIO
from pathlib import Path
from typing import Any

from productfix.storage import list_products, tenant_db_path, upsert_products


def parse_csv_content(content: bytes) -> list[dict[str, Any]]:
    decoded = content.decode("utf-8-sig")
    return list(csv.DictReader(StringIO(decoded)))


def import_products_from_csv(tenant_id: str, content: bytes) -> dict[str, Any]:
    rows = parse_csv_content(content)
    imported = upsert_products(tenant_id, rows)
    return {
        "imported_products": imported,
        "products": list_products(tenant_id),
    }


def get_tenant_products(tenant_id: str) -> list[dict[str, Any]]:
    return list_products(tenant_id)


def get_tenant_database_path(tenant_id: str) -> Path:
    return tenant_db_path(tenant_id)
