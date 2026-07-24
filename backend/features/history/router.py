import calendar
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from datetime import date
from core.database import get_db

router = APIRouter(tags=["Daily Tracks"])

@router.get("/daily/summary/{year}/{month}")
async def get_monthly_summary(year: int, month: int, db: AsyncSession = Depends(get_db)):
    """
    Returns a lightweight summary of all tracked days in the given month.
    """
    if month < 1 or month > 12:
        raise HTTPException(status_code=400, detail="Invalid month")
        
    _, last_day = calendar.monthrange(year, month)
    start_date = date(year, month, 1)
    end_date = date(year, month, last_day)
    
    query = text("""
        SELECT date, point_count, total_distance_m, timeline_json,
               (snapped_line IS NOT NULL OR raw_line IS NOT NULL) AS has_route
        FROM daily_tracks
        WHERE date >= :start_date AND date <= :end_date
        ORDER BY date ASC
    """)
    
    result = await db.execute(query, {"start_date": start_date, "end_date": end_date})
    rows = result.fetchall()
    
    total_distance = 0
    total_points = 0
    moving_time_sec = 0
    stationary_time_sec = 0
    
    daily_summaries = []
    
    for row in rows:
        d = row.date
        date_str = d.isoformat()
        
        has_timeline = bool(row.timeline_json)
        daily_moving = 0
        daily_stationary = 0
        
        if has_timeline:
            summary = row.timeline_json.get("summary", {})
            daily_moving = summary.get("moving_time_sec", 0)
            daily_stationary = summary.get("stationary_time_sec", 0)
            
            moving_time_sec += daily_moving
            stationary_time_sec += daily_stationary
            
        total_distance += row.total_distance_m or 0
        total_points += row.point_count or 0
        
        daily_summaries.append({
            "date": date_str,
            "day_of_week": d.isoweekday(),
            "point_count": row.point_count,
            "distance_m": row.total_distance_m,
            "has_route": row.has_route,
            "has_timeline": has_timeline,
            "moving_time_sec": daily_moving,
            "stationary_time_sec": daily_stationary
        })
        
    active_days_count = len(daily_summaries)
    average_daily_distance = total_distance / active_days_count if active_days_count > 0 else 0
    
    return {
        "version": 1,
        "year": year,
        "month": month,
        "summary": {
            "active_days_count": active_days_count,
            "total_points": total_points,
            "total_distance_m": total_distance,
            "average_daily_distance_m": average_daily_distance,
            "moving_time_sec": moving_time_sec,
            "stationary_time_sec": stationary_time_sec,
        },
        "active_days": daily_summaries
    }

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

@router.get("/daily/{track_date}/timeline")
async def get_daily_timeline(track_date: date, db: AsyncSession = Depends(get_db)):
    """
    Returns the chronological timeline of events (Stops and Moving) for a specific date.
    Calculates summary statistics and caches them in the daily_tracks table.
    """
    from features.tracking.timeline_service import TimelineService
    service = TimelineService(db)
    return await service.get_timeline_for_date(track_date)

