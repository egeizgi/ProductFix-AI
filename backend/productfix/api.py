from __future__ import annotations

import csv
from io import StringIO

from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .analysis import analyze_products

app = FastAPI(title="ProductFix AI API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/analyze")
async def analyze(file: UploadFile = File(...)) -> dict:
    content = (await file.read()).decode("utf-8-sig")
    rows = list(csv.DictReader(StringIO(content)))
    return analyze_products(rows)
