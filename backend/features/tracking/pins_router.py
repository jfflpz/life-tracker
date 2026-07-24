from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from features.tracking import schemas, models
from core.database import get_db
from datetime import date
import json

router = APIRouter(tags=["Pins"])

@router.post("/pins", response_model=schemas.PinnedLocationResponse)
async def create_pin(pin: schemas.PinnedLocationCreate, db: AsyncSession = Depends(get_db)):
    lon, lat = pin.location
    pin_wkt = f"SRID=4326;POINT({lon} {lat})"
    
    query = text("""
        INSERT INTO pinned_locations (id, label, icon, location, radius_m)
        VALUES (gen_random_uuid(), :label, :icon, ST_GeomFromEWKT(:location), :radius_m)
        RETURNING id, label, icon, radius_m
    """)
    
    result = await db.execute(query, {
        "label": pin.label,
        "icon": pin.icon,
        "location": pin_wkt,
        "radius_m": pin.radius_m
    })
    
    # Invalidate all timeline caches because a new pin could match past stops
    await db.execute(text("UPDATE daily_tracks SET timeline_json = NULL"))
    
    await db.commit()
    row = result.fetchone()
    
    return {
        "id": row.id,
        "label": row.label,
        "icon": row.icon,
        "location": [lon, lat],
        "radius_m": row.radius_m
    }


@router.get("/pins")
async def get_all_pins(db: AsyncSession = Depends(get_db)):
    query = text("""
        SELECT id, label, icon, radius_m, ST_X(location::geometry) as lon, ST_Y(location::geometry) as lat
        FROM pinned_locations
    """)
    result = await db.execute(query)
    rows = result.fetchall()
    
    return [
        {
            "id": row.id,
            "label": row.label,
            "icon": row.icon,
            "location": [row.lon, row.lat],
            "radius_m": row.radius_m
        } for row in rows
    ]

@router.delete("/pins/{pin_id}")
async def delete_pin(pin_id: str, db: AsyncSession = Depends(get_db)):
    query = text("DELETE FROM pinned_locations WHERE id = :id")
    await db.execute(query, {"id": pin_id})
    # Invalidate all timeline caches because past stops may have used this pin
    await db.execute(text("UPDATE daily_tracks SET timeline_json = NULL"))
    await db.commit()
    return {"message": "Deleted successfully"}

@router.get("/pins/visits/{visit_date}")
async def get_visited_pins(visit_date: date, db: AsyncSession = Depends(get_db)):
    """
    Finds which pinned locations were visited on a specific date.
    A pin is "visited" if any GPS point from that day falls within the pin's geofence radius.
    """
    
    query = text("""
    SELECT DISTINCT p.id, p.label
    FROM pinned_locations p
    JOIN gps_points g ON ST_DWithin(g.location::geography, p.location::geography, p.radius_m)
    WHERE DATE(g.recorded_at) = :visit_date
    """)
    
    result = await db.execute(query, {"visit_date": visit_date})
    rows = result.fetchall()
    
    return {"visited_pins": [{"id": row.id, "label": row.label} for row in rows]}
