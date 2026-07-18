from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from datetime import date
import json

from database import get_db
from services.osrm import match_route

router = APIRouter(tags=["Snap"])

@router.post("/snap/{track_date}")
async def snap_daily_track(track_date: date, db: AsyncSession = Depends(get_db)):
    """
    1. Fetches all GPS points for a given day, ordered by time.
    2. Sends them to OSRM to get the road-snapped GeoJSON.
    3. Saves the GeoJSON into daily_tracks.snapped_line.
    """
    
    # 1. Fetch raw points from the database
    query = text("""
        SELECT ST_X(location::geometry) as lon, ST_Y(location::geometry) as lat
        FROM gps_points
        WHERE DATE(recorded_at) = :track_date
        ORDER BY recorded_at ASC
    """)
    result = await db.execute(query, {"track_date": track_date})
    rows = result.fetchall()
    
    if len(rows) < 2:
        raise HTTPException(status_code=400, detail="Not enough points to snap.")
        
    coordinates = [(row.lon, row.lat) for row in rows]
    
    # 2. TODO: Call our OSRM service to get the snapped geometry
    # geometry = await ...
    
    geometry = await match_route(coordinates)
    
    # We convert the GeoJSON dictionary back to a JSON string so PostGIS can parse it
    geometry_json_str = json.dumps(geometry)
    
    # 3. TODO: Write an UPDATE query to save the snapped line.
    # We use ST_GeomFromGeoJSON(:geojson) to convert the JSON string into PostGIS geometry.
    # Update the daily_tracks table where date = :track_date.
    
    update_query = text("UPDATE daily_tracks SET snapped_line = ST_GeomFromGeoJSON(:geojson) WHERE date = :track_date")
    await db.execute(update_query, {"geojson": geometry_json_str, "track_date": track_date})
    await db.commit()
    
    return {"message": "Track successfully snapped to roads!"}
