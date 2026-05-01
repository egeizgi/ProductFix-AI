# ProductFix AI

ProductFix AI is a SaaS-style MVP for ecommerce teams that want to understand why products are not converting, why customers return them, and what should be fixed first.

## Problem

E-commerce mağazalarında bazı ürünler çok görüntülenir ama sepete eklenmez, bazıları satılır ama çok iade edilir. Mağaza sahipleri bunun nedenini manuel yorumlardan, iade sebeplerinden ve ürün sayfası eksiklerinden anlamaya çalışır.

## Solution

ProductFix AI, ürün verilerini analiz ederek düşük dönüşüm ve yüksek iade riskine sahip ürünleri bulur. Ürün açıklaması, yorumlar, iade sebepleri, fotoğraf sayısı, beden tablosu gibi sinyalleri kullanarak mağaza sahibine uygulanabilir düzeltme önerileri sunar.

The app turns raw product CSV data into:

- Product risk scores
- Return reason analysis
- Missing product page signal detection
- AI-style description and buyer warning suggestions
- A Fix Center where actions can be marked as completed
- Tenant-specific persistent databases for SaaS customers

## Screenshots

### Dashboard

![Dashboard screenshot](docs/screenshots/dashboard.png)

### Product Risk List

![Product risk list screenshot](docs/screenshots/product-risk-list.png)

### Fix Center

![Fix Center screenshot](docs/screenshots/fix-center.png)

## Demo Flow

1. Sample CSV upload
2. Product risk scores are generated
3. Return reasons are analyzed
4. Fix Center suggests actions
5. User marks fixes as completed

## Features

- Dashboard for conversion, return, and risk signals
- Products view with per-product improvement recommendations
- Return analysis with category and theme breakdowns
- Fix Center for prioritized actions
- Completed fix tracking that survives page reloads
- CSV paste input and manual product entry
- Turkish / English UI language switch
- Light / dark background mode
- Tenant-specific SQLite databases under `backend/data/tenants/`

## Project Layout

- `frontend/`: Flutter app
- `backend/`: Python FastAPI analysis service
- `backend/data/sample-products.csv`: demo CSV file

No virtualenv is created by this repo. Use your own conda environment.

## Quick Start

### Backend

```powershell
cd backend
pip install -r requirements.txt
uvicorn productfix.api:app --reload
```

Run the sample analysis without starting the API:

```powershell
cd backend
python -m productfix.sample_run
```

### Frontend

Flutter is expected to be available in your environment.

```powershell
cd frontend
flutter pub get
flutter run
```

## Demo Data

Use `backend/data/sample-products.csv` as the starting template.

Required columns:

- `sku`
- `name`
- `category`
- `views`
- `add_to_cart`
- `purchases`
- `returns`
- `description`
- `reviews`
- `return_reasons`
- `photo_count`
- `has_size_chart`
- `has_model_photo`

## SaaS Persistence

The API persists uploaded CSV data per SaaS customer. Each `tenant_id` gets its own SQLite database under `backend/data/tenants/`, so customers do not have to upload the same CSV again.

Useful endpoints:

- `POST /tenants/{tenant_id}/products/import-csv`: import or update products from a CSV file, then return the tenant analysis.
- `GET /tenants/{tenant_id}/products`: list the products already stored for that tenant.
- `GET /tenants/{tenant_id}/analysis`: analyze the tenant's stored products without uploading another CSV.
- `POST /tenants/{tenant_id}/fixes/{fix_id}/complete`: mark a fix as completed or reopen it with `{ "completed": false }`.
- `GET /tenants/{tenant_id}/fixes/completed`: list completed fixes.

## API Smoke Test

After starting the backend, upload the sample CSV for a demo tenant:

```powershell
curl.exe -X POST "http://127.0.0.1:8000/tenants/demo-store/products/import-csv" `
  -F "file=@backend/data/sample-products.csv"
```
