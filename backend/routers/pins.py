from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from datetime import date
from database import get_db
import schemas
import json

router = APIRouter(tags=["Pins"])

@router.post("/pins", response_model=schemas.PinnedLocationResponse)
async def create_pin(pin: schemas.PinnedLocationCreate, db: AsyncSession = Depends(get_db)):
    lon, lat = pin.location
    pin_wkt = f"SRID=4326;POINT({lon} {lat})"
    
    query = text("""
        INSERT INTO pinned_locations (label, icon, location, radius_m)
        VALUES (:label, :icon, :location::geometry, :radius_m)
        RETURNING id, label, icon, radius_m
    """)
    
    result = await db.execute(query, {
        "label": pin.label,
        "icon": pin.icon,
        "location": pin_wkt,
        "radius_m": pin.radius_m
    })
    await db.commit()
    row = result.fetchone()
    
    return {
        "id": row.id,
        "label": row.label,
        "icon": row.icon,
        "location": [lon, lat],
        "radius_m": row.radius_m
    }


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
