from __future__ import annotations

import re
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

PRODUCT_COLUMNS = (
    "sku",
    "name",
    "category",
    "views",
    "add_to_cart",
    "purchases",
    "returns",
    "description",
    "reviews",
    "return_reasons",
    "photo_count",
    "has_size_chart",
    "has_model_photo",
)

TENANT_DB_DIR = Path(__file__).resolve().parents[1] / "data" / "tenants"


def tenant_db_path(tenant_id: str) -> Path:
    safe_tenant = _safe_tenant_id(tenant_id)
    return TENANT_DB_DIR / f"{safe_tenant}.db"


@contextmanager
def tenant_connection(tenant_id: str) -> Iterator[sqlite3.Connection]:
    TENANT_DB_DIR.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(tenant_db_path(tenant_id))
    connection.row_factory = sqlite3.Row
    try:
        _ensure_schema(connection)
        yield connection
        connection.commit()
    finally:
        connection.close()


def upsert_products(tenant_id: str, rows: list[dict[str, Any]]) -> int:
    with tenant_connection(tenant_id) as connection:
        for row in rows:
            product = _normalize_product_row(row)
            connection.execute(
                """
                INSERT INTO products (
                    sku, name, category, views, add_to_cart, purchases, returns,
                    description, reviews, return_reasons, photo_count,
                    has_size_chart, has_model_photo
                )
                VALUES (
                    :sku, :name, :category, :views, :add_to_cart, :purchases,
                    :returns, :description, :reviews, :return_reasons,
                    :photo_count, :has_size_chart, :has_model_photo
                )
                ON CONFLICT(sku) DO UPDATE SET
                    name = excluded.name,
                    category = excluded.category,
                    views = excluded.views,
                    add_to_cart = excluded.add_to_cart,
                    purchases = excluded.purchases,
                    returns = excluded.returns,
                    description = excluded.description,
                    reviews = excluded.reviews,
                    return_reasons = excluded.return_reasons,
                    photo_count = excluded.photo_count,
                    has_size_chart = excluded.has_size_chart,
                    has_model_photo = excluded.has_model_photo,
                    updated_at = CURRENT_TIMESTAMP
                """,
                product,
            )
    return len(rows)


def list_products(tenant_id: str) -> list[dict[str, Any]]:
    with tenant_connection(tenant_id) as connection:
        rows = connection.execute(
            """
            SELECT sku, name, category, views, add_to_cart, purchases, returns,
                   description, reviews, return_reasons, photo_count,
                   has_size_chart, has_model_photo
            FROM products
            ORDER BY updated_at DESC, sku ASC
            """
        ).fetchall()
    return [_row_to_product(row) for row in rows]


def complete_fix(
    tenant_id: str,
    fix_id: str,
    *,
    sku: str,
    title: str,
    detail: str = "",
) -> dict[str, Any]:
    with tenant_connection(tenant_id) as connection:
        connection.execute(
            """
            INSERT INTO completed_fixes (fix_id, sku, title, detail)
            VALUES (:fix_id, :sku, :title, :detail)
            ON CONFLICT(fix_id) DO UPDATE SET
                sku = excluded.sku,
                title = excluded.title,
                detail = excluded.detail,
                completed_at = CURRENT_TIMESTAMP
            """,
            {"fix_id": fix_id, "sku": sku, "title": title, "detail": detail},
        )
    return {"fix_id": fix_id, "sku": sku, "title": title, "completed": True}


def reopen_fix(
    tenant_id: str,
    fix_id: str,
    *,
    sku: str = "",
    title: str = "",
) -> dict[str, Any]:
    with tenant_connection(tenant_id) as connection:
        connection.execute(
            "DELETE FROM completed_fixes WHERE fix_id = :fix_id",
            {"fix_id": fix_id},
        )
        if sku and title:
            rows = connection.execute(
                "SELECT fix_id, title FROM completed_fixes WHERE sku = :sku",
                {"sku": sku},
            ).fetchall()
            matching_ids = [
                row["fix_id"]
                for row in rows
                if _match_key(sku, row["title"]) == _match_key(sku, title)
            ]
            for matching_id in matching_ids:
                connection.execute(
                    "DELETE FROM completed_fixes WHERE fix_id = :fix_id",
                    {"fix_id": matching_id},
                )
    return {"fix_id": fix_id, "completed": False}


def list_completed_fixes(tenant_id: str) -> list[dict[str, Any]]:
    with tenant_connection(tenant_id) as connection:
        rows = connection.execute(
            """
            SELECT fix_id, sku, title, detail, completed_at
            FROM completed_fixes
            ORDER BY completed_at DESC
            """
        ).fetchall()
    return [
        {
            **dict(row),
            "match_key": _match_key(row["sku"], row["title"]),
        }
        for row in rows
    ]


def _ensure_schema(connection: sqlite3.Connection) -> None:
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS products (
            sku TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            views INTEGER NOT NULL DEFAULT 0,
            add_to_cart INTEGER NOT NULL DEFAULT 0,
            purchases INTEGER NOT NULL DEFAULT 0,
            returns INTEGER NOT NULL DEFAULT 0,
            description TEXT NOT NULL DEFAULT '',
            reviews TEXT NOT NULL DEFAULT '',
            return_reasons TEXT NOT NULL DEFAULT '',
            photo_count INTEGER NOT NULL DEFAULT 0,
            has_size_chart INTEGER NOT NULL DEFAULT 0,
            has_model_photo INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS completed_fixes (
            fix_id TEXT PRIMARY KEY,
            sku TEXT NOT NULL,
            title TEXT NOT NULL,
            detail TEXT NOT NULL DEFAULT '',
            completed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )


def _normalize_product_row(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "sku": str(row.get("sku") or "-").strip() or "-",
        "name": str(row.get("name") or "Adsiz urun"),
        "category": str(row.get("category") or "Genel"),
        "views": _number(row.get("views")),
        "add_to_cart": _number(row.get("add_to_cart")),
        "purchases": _number(row.get("purchases")),
        "returns": _number(row.get("returns")),
        "description": str(row.get("description") or ""),
        "reviews": str(row.get("reviews") or ""),
        "return_reasons": str(row.get("return_reasons") or ""),
        "photo_count": _number(row.get("photo_count")),
        "has_size_chart": int(_boolean(row.get("has_size_chart"))),
        "has_model_photo": int(_boolean(row.get("has_model_photo"))),
    }


def _row_to_product(row: sqlite3.Row) -> dict[str, Any]:
    product = dict(row)
    product["has_size_chart"] = bool(product["has_size_chart"])
    product["has_model_photo"] = bool(product["has_model_photo"])
    return product


def _safe_tenant_id(tenant_id: str) -> str:
    value = tenant_id.strip().lower()
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{1,62}", value):
        raise ValueError(
            "tenant_id must be 2-63 chars and contain only letters, numbers, '-' or '_'"
        )
    return value


def _match_key(sku: str, title: str) -> str:
    return f"{sku.strip().upper()}:{_normalize_title(title)}"


def _normalize_title(title: str) -> str:
    replacements = str.maketrans(
        {
            "ı": "i",
            "İ": "i",
            "ğ": "g",
            "Ğ": "g",
            "ü": "u",
            "Ü": "u",
            "ş": "s",
            "Ş": "s",
            "ö": "o",
            "Ö": "o",
            "ç": "c",
            "Ç": "c",
        }
    )
    normalized = title.strip().lower().translate(replacements)
    return re.sub(r"(^-+|-+$)", "", re.sub(r"[^a-z0-9]+", "-", normalized))


def _number(value: Any) -> int:
    try:
        return int(float(str(value or 0).replace(",", ".")))
    except ValueError:
        return 0


def _boolean(value: Any) -> bool:
    return str(value).strip().lower() in {"true", "yes", "1", "evet"}
