# 📍 Personal GPS Life Tracker Backend

A Python backend built with **FastAPI** and **PostGIS** designed to handle 24/7 time-series GPS data ingestion from a mobile device (like a personal Google Timeline).

This is **Project C (Phase 1)** in my learning journey. It builds on the foundational spatial data engineering skills from previous projects and introduces advanced concepts like offline-first batch syncing, spatial geofencing (`ST_DWithin`), and road-snapping via OSRM map matching.

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | FastAPI (Async) |
| **Database** | PostgreSQL + PostGIS |
| **ORM** | SQLAlchemy 2.0 + GeoAlchemy2 |
| **Data Validation** | Pydantic |
| **Road Snapping** | OSRM (Docker) |

## Key Features

1. **Batched GPS Ingestion**: Highly efficient `POST /api/v1/points/batch` endpoint to save mobile battery by receiving points in batches.
2. **Dynamic GeoJSON Generation**: `GET /api/v1/daily/{date}` uses raw PostGIS SQL (`ST_AsGeoJSON`) to return map-ready GeoJSON directly from the database.
3. **Spatial Geofencing**: `GET /api/v1/pins/visits/{date}` uses PostGIS `ST_DWithin` and spatial indexing to quickly determine if a user visited any pinned location on a specific day.
4. **Time-Series Tracking**: Differentiates between `recorded_at` (device time) and `received_at` (server time) for robust offline-first tracking.

## Getting Started

### 1. Database Setup
Start a PostGIS docker container, then create the database:
```bash
docker start postgis
docker exec -it postgis psql -U geo_user -d postgres -c "CREATE DATABASE life_tracker;"
docker exec -it postgis psql -U geo_user -d life_tracker -c "CREATE EXTENSION IF NOT EXISTS postgis;"
```

### 2. Python Setup
Create a virtual environment and install dependencies:
```bash
python -m venv venv
source venv/bin/activate
pip install fastapi uvicorn sqlalchemy asyncpg geoalchemy2 pydantic httpx
```

### 3. Initialize Tables
```bash
python init_db.py
```

### 4. OSRM Setup (Map Matching)
Download the map data and start the OSRM docker container:
```bash
wget http://download.geofabrik.de/asia/philippines-latest.osm.pbf -P osrm-data/
# Run extraction/partitioning (see roadmap for exact commands)
docker compose up -d
```

### 4. Run the API
```bash
uvicorn main:app --reload
```
Navigate to `http://localhost:8000/docs` to test the endpoints in the Swagger UI.
