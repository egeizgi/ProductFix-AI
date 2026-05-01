from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class IssueRule:
    key: str
    label: str
    words: tuple[str, ...]
    fix: str


ISSUE_RULES = (
    IssueRule(
        key="size",
        label="Beden/Kalip belirsizligi",
        words=("beden", "kalip", "kalıp", "numara", "dar", "buyuk", "büyük", "kucuk", "küçük", "boy"),
        fix="Beden veya kalip bilgisini fiyatın hemen altına taşı.",
    ),
    IssueRule(
        key="color",
        label="Gorsel beklenti farki",
        words=("renk", "fotograf", "fotoğraf", "gorsel", "görsel", "koyu", "acik", "açık"),
        fix="Ürün görsellerine doğal ışık ve gerçek kullanım fotoğrafı ekle.",
    ),
    IssueRule(
        key="quality",
        label="Kalite algisi",
        words=("kumas", "kumaş", "ince", "kalite", "sert", "yumusak", "yumuşak", "malzeme"),
        fix="Malzeme, doku ve kullanım hissini açıklamaya net ekle.",
    ),
    IssueRule(
        key="technical",
        label="Teknik bilgi eksikligi",
        words=("baglanti", "bağlantı", "pil", "icerik", "içerik", "kutu", "olcu", "ölçü", "ozellik", "özellik"),
        fix="Teknik özellikleri madde madde ve eksiksiz göster.",
    ),
)


def analyze_products(rows: list[dict[str, Any]]) -> dict[str, Any]:
    products = [analyze_product(row) for row in rows]
    themes = _theme_counts(products)
    actions = _fix_actions(products)

    average_score = round(sum(product["score"] for product in products) / len(products)) if products else 0

    return {
        "summary": {
            "total_products": len(products),
            "average_score": average_score,
            "high_risk_products": sum(1 for product in products if product["risk"] == "high"),
            "top_problem": themes[0]["label"] if themes else None,
        },
        "products": sorted(products, key=lambda product: product["score"]),
        "themes": themes,
        "fix_center": actions,
    }


def analyze_product(row: dict[str, Any]) -> dict[str, Any]:
    product = _normalize(row)
    combined_text = f"{product['description']} {product['reviews']} {product['return_reasons']}".lower()
    issues = [rule for rule in ISSUE_RULES if any(word in combined_text for word in rule.words)]

    conversion_rate = _safe_rate(product["purchases"], product["views"])
    cart_conversion_rate = _safe_rate(product["purchases"], product["add_to_cart"])
    return_rate = _safe_rate(product["returns"], product["purchases"])
    missing = _missing_info(product)

    issue_penalty = len(issues) * 8
    return_penalty = min(35, round(return_rate * 180))
    conversion_penalty = 16 if conversion_rate < 0.04 else 8 if conversion_rate < 0.08 else 0
    cart_penalty = 10 if cart_conversion_rate < 0.25 else 5 if cart_conversion_rate < 0.4 else 0
    missing_penalty = len(missing) * 7
    score = _clamp(100 - issue_penalty - return_penalty - conversion_penalty - cart_penalty - missing_penalty, 0, 100)
    risk = "high" if score < 50 or return_rate > 0.22 else "medium" if score < 70 or return_rate > 0.12 else "low"

    issue_payloads = [{"key": rule.key, "label": rule.label, "fix": rule.fix} for rule in issues]

    return {
        **product,
        "score": score,
        "risk": risk,
        "conversion_rate": round(conversion_rate, 4),
        "cart_conversion_rate": round(cart_conversion_rate, 4),
        "return_rate": round(return_rate, 4),
        "issues": issue_payloads,
        "missing_info": missing,
        "suggested_description": _suggested_description(product, issue_payloads, missing),
        "buyer_warning": _buyer_warning(product, issue_payloads),
    }


def _normalize(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "sku": str(row.get("sku") or "-"),
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
        "has_size_chart": _boolean(row.get("has_size_chart")),
        "has_model_photo": _boolean(row.get("has_model_photo")),
    }


def _missing_info(product: dict[str, Any]) -> list[str]:
    missing = []
    category = product["category"].lower()
    description = product["description"].lower()

    if len(product["description"]) < 80:
        missing.append("Aciklama kisa")
    if not product["has_size_chart"] and category in {"giyim", "ayakkabi", "ayakkabı"}:
        missing.append("Beden tablosu yok")
    if not product["has_model_photo"]:
        missing.append("Kullanim/model fotografi yok")
    if product["photo_count"] < 4:
        missing.append("Fotograf sayisi az")
    if not any(token in description for token in ("olcu", "ölç", "beden", "numara")):
        missing.append("Olcu bilgisi zayif")

    return missing


def _suggested_description(product: dict[str, Any], issues: list[dict[str, str]], missing: list[str]) -> str:
    issue_text = ", ".join(issue["label"].lower() for issue in issues) or "urun beklentisi"
    missing_text = f" Eksik kalan alanlar: {', '.join(missing)}." if missing else ""
    base = product["description"] or f"{product['name']} icin aciklama hazirlanmali."

    return (
        f"{base} Bu ürün sayfası özellikle {issue_text} konusunda netleştirilmeli."
        f"{missing_text} Müşteri satın almadan önce doğru beklenti kurmalı."
    )


def _buyer_warning(product: dict[str, Any], issues: list[dict[str, str]]) -> str:
    if not issues:
        return "Bu ürün için satın alma öncesi ekstra uyarı gerekmiyor."

    primary = issues[0]["key"]
    if primary == "size":
        return "Mini uyarı: Bu üründe beden/kalıp yorumu hassas. Satın almadan önce beden bilgisini kontrol edin."
    if primary == "color":
        return "Mini uyarı: Ürün rengi ışık ve ekran ayarlarına göre farklı algılanabilir."
    if primary == "technical":
        return "Mini uyarı: Teknik özellikleri ve kutu içeriğini satın almadan önce kontrol edin."
    return f"Mini uyarı: {product['name']} için müşteri beklentisini netleştiren kısa bir not göster."


def _theme_counts(products: list[dict[str, Any]]) -> list[dict[str, Any]]:
    themes = []
    for rule in ISSUE_RULES:
        count = sum(1 for product in products if any(issue["key"] == rule.key for issue in product["issues"]))
        if count:
            themes.append({"key": rule.key, "label": rule.label, "fix": rule.fix, "count": count})

    return sorted(themes, key=lambda theme: theme["count"], reverse=True)


def _fix_actions(products: list[dict[str, Any]]) -> list[dict[str, Any]]:
    actions = []
    for product in products:
        for issue in product["issues"]:
            actions.append(
                {
                    "sku": product["sku"],
                    "product": product["name"],
                    "score": product["score"],
                    "risk": product["risk"],
                    "title": issue["fix"],
                    "detail": f"{product['name']}: {issue['label']} sinyali yorum ve iade metinlerinde tekrar ediyor.",
                }
            )
        for missing in product["missing_info"]:
            actions.append(
                {
                    "sku": product["sku"],
                    "product": product["name"],
                    "score": product["score"],
                    "risk": product["risk"],
                    "title": missing,
                    "detail": f"{product['name']}: ürün sayfasında bu bilgi eksik veya zayıf görünüyor.",
                }
            )

    return sorted(actions, key=lambda action: (action["risk"] != "high", action["score"]))[:12]


def _number(value: Any) -> int:
    try:
        return int(float(str(value or 0).replace(",", ".")))
    except ValueError:
        return 0


def _boolean(value: Any) -> bool:
    return str(value).strip().lower() in {"true", "yes", "1", "evet"}


def _safe_rate(part: int, total: int) -> float:
    return part / total if total else 0


def _clamp(value: int, minimum: int, maximum: int) -> int:
    return max(minimum, min(maximum, value))
