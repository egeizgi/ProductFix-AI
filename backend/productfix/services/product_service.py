from __future__ import annotations

import csv
from io import StringIO
from pathlib import Path
from typing import Any

from productfix.storage import (
    PRODUCT_COLUMNS,
    list_products,
    tenant_db_path,
    upsert_products,
)

NUMERIC_COLUMNS = {"views", "add_to_cart", "purchases", "returns", "photo_count"}
BOOLEAN_COLUMNS = {"has_size_chart", "has_model_photo"}


def parse_csv_content(content: bytes) -> list[dict[str, Any]]:
    decoded = content.decode("utf-8-sig")
    reader = csv.DictReader(StringIO(decoded))
    headers = [header.strip() for header in reader.fieldnames or []]
    normalized_headers = {header.lower() for header in headers}

    for column in PRODUCT_COLUMNS:
        if column not in normalized_headers:
            raise ValueError(f"{column} kolonu eksik")

    rows = [
        {
            str(key).strip().lower(): value
            for key, value in row.items()
            if key is not None
        }
        for row in reader
    ]
    rows = [
        row
        for row in rows
        if any(str(value or "").strip() for value in row.values())
    ]
    if not rows:
        raise ValueError("CSV içinde en az bir ürün satırı olmalı")

    for index, row in enumerate(rows, start=2):
        sku = str(row.get("sku") or "").strip()
        if not sku:
            raise ValueError(f"{index}. satırda sku boş olamaz")

        for column in NUMERIC_COLUMNS:
            value = str(row.get(column) or "").strip()
            if not value or not value.isdigit():
                raise ValueError(f"{column} sayısal olmalı")

        for column in BOOLEAN_COLUMNS:
            value = str(row.get(column) or "").strip().lower()
            if value not in {"true", "false"}:
                raise ValueError(f"{column} true/false olmalı")

    return rows


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
