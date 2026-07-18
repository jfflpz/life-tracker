from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from datetime import date
from database import get_db

router = APIRouter(tags=["Daily Tracks"])

@router.get("/daily/{track_date}")
async def get_daily_track(track_date: date, db: AsyncSession = Depends(get_db)):
    """
    Returns the daily track as a GeoJSON FeatureCollection.
    If we have a snapped_line (from OSRM), we return that. 
    Otherwise, we return the raw_line.
    """
    
    query = text("""SELECT id, total_distance_m, point_count,
                    ST_AsGeoJSON(COALESCE(snapped_line, raw_line)) AS geojson
                    FROM daily_tracks
                    WHERE date = :track_date""")
    
    result = await db.execute(query, {"track_date": track_date})
    row = result.fetchone()
    
    if not row:
        raise HTTPException(status_code=404, detail="No track found for this date")
        
    import json
    feature = {
        "type": "Feature",
        "properties": {
            "id": str(row.id),
            "date": str(track_date),
            "distance_m": row.total_distance_m,
            "points": row.point_count
        },
        "geometry": json.loads(row.geojson)
    }
    
    return {
        "type": "FeatureCollection",
        "features": [feature]
    }
