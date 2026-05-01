# ProductFix AI

ProductFix AI is an MVP for finding why ecommerce products are not converting or are being returned.

Project layout:

- `frontend/`: Flutter app
- `backend/`: Python analysis service

No virtualenv is created by this repo. Use your own conda environment.

## Backend

```powershell
cd backend
python -m productfix.sample_run
```

Optional API run, after installing dependencies in your conda env:

```powershell
cd backend
pip install -r requirements.txt
uvicorn productfix.api:app --reload
```

## Frontend

Flutter is expected to be available in your environment.

```powershell
cd frontend
flutter pub get
flutter run
```

The Flutter MVP includes:

- Dashboard
- Products
- Returns analysis with charts
- Fix Center
- CSV paste input
- Manual product input that is converted into the same CSV-compatible product model before analysis

## CSV Format

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
