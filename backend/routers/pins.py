from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from datetime import date
from database import get_db

router = APIRouter(tags=["Pins"])


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
