from __future__ import annotations

from productfix.analysis import analyze_product, analyze_products


def test_high_return_product_is_high_risk() -> None:
    row = {
        "sku": "TSHIRT-001",
        "name": "Basic T-Shirt",
        "category": "giyim",
        "views": "1000",
        "add_to_cart": "100",
        "purchases": "50",
        "returns": "20",
        "description": "Kısa açıklama",
        "reviews": "beden dar geldi",
        "return_reasons": "beden küçük",
        "photo_count": "2",
        "has_size_chart": "false",
        "has_model_photo": "false",
    }

    result = analyze_product(row)

    assert result["risk"] == "high"
    assert result["return_rate"] > 0.2
    assert any(issue["key"] == "size" for issue in result["issues"])


def test_new_commerce_issue_rules_are_detected() -> None:
    row = {
        "sku": "WATCH-001",
        "name": "Smart Watch",
        "category": "elektronik",
        "views": "2000",
        "add_to_cart": "200",
        "purchases": "80",
        "returns": "5",
        "description": "Akıllı saat, garanti ve orijinal ürün bilgisi var.",
        "reviews": "Fiyat pahalı ama kampanya olursa eder. Kargo geç geldi.",
        "return_reasons": "paket hasarlı geldi",
        "photo_count": "5",
        "has_size_chart": "false",
        "has_model_photo": "true",
    }

    result = analyze_product(row)
    issue_keys = {issue["key"] for issue in result["issues"]}

    assert {"price", "shipping", "trust"}.issubset(issue_keys)


def test_analyze_products_returns_sorted_fix_center() -> None:
    payload = analyze_products(
        [
            {
                "sku": "LOW-001",
                "name": "Low Risk",
                "category": "aksesuar",
                "views": "1000",
                "add_to_cart": "300",
                "purchases": "200",
                "returns": "2",
                "description": "Uzun ve net açıklama beden ölçü malzeme kullanım detayları ile dolu.",
                "reviews": "güzel ürün",
                "return_reasons": "",
                "photo_count": "6",
                "has_size_chart": "true",
                "has_model_photo": "true",
            },
            {
                "sku": "HIGH-001",
                "name": "High Risk",
                "category": "giyim",
                "views": "1000",
                "add_to_cart": "100",
                "purchases": "50",
                "returns": "18",
                "description": "Kısa",
                "reviews": "beden dar",
                "return_reasons": "beden küçük",
                "photo_count": "1",
                "has_size_chart": "false",
                "has_model_photo": "false",
            },
        ]
    )

    assert payload["summary"]["total_products"] == 2
    assert payload["summary"]["high_risk_products"] == 1
    assert payload["fix_center"][0]["sku"] == "HIGH-001"
