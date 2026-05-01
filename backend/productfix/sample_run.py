from __future__ import annotations

import csv
import json
from pathlib import Path

from .analysis import analyze_products


def main() -> None:
    sample_path = Path(__file__).resolve().parents[1] / "data" / "sample-products.csv"
    with sample_path.open(encoding="utf-8-sig", newline="") as file:
        rows = list(csv.DictReader(file))

    print(json.dumps(analyze_products(rows), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
