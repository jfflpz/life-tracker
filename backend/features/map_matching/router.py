from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from datetime import date
import json

from core.database import get_db
from features.map_matching.osrm_service import match_route

router = APIRouter(tags=["Snap"])

@router.post("/snap/{track_date}")
async def snap_daily_track(track_date: date, db: AsyncSession = Depends(get_db)):
    """
    1. Fetches all GPS points for a given day, ordered by time.
    2. Sends them to OSRM's Map Matching API to get a road-snapped GeoJSON.
    3. Saves the GeoJSON into daily_tracks.snapped_line.
    """
    
    # Fetch coordinates AND timestamps so OSRM can understand the temporal sequence
    query = text("""
        SELECT DISTINCT ON (recorded_at) 
            ST_X(location::geometry) as lon, 
            ST_Y(location::geometry) as lat,
            EXTRACT(EPOCH FROM recorded_at)::bigint as timestamp
        FROM gps_points
        WHERE DATE(recorded_at AT TIME ZONE 'Asia/Manila') = :track_date
        ORDER BY recorded_at ASC
    """)
    result = await db.execute(query, {"track_date": track_date})
    rows = result.fetchall()
    
    if len(rows) < 2:
        raise HTTPException(status_code=400, detail="Not enough points to snap.")
        
    coordinates = [(row.lon, row.lat) for row in rows]
    timestamps = [row.timestamp for row in rows]
    
    geometry = await match_route(coordinates, timestamps)
    
    geometry_json_str = json.dumps(geometry)
    
    update_query = text("UPDATE daily_tracks SET snapped_line = ST_GeomFromGeoJSON(:geojson) WHERE date = :track_date")
    await db.execute(update_query, {"geojson": geometry_json_str, "track_date": track_date})
    await db.commit()
    
    return {"message": "Track successfully snapped to roads!"}
