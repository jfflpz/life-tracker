from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from datetime import datetime, timezone
from features.tracking import models, schemas
from core.database import get_db

router = APIRouter(tags=["Points"])

@router.post("/points/batch")
async def ingest_gps_batch(batch: schemas.GPSBatchCreate, db: AsyncSession = Depends(get_db)):
    """
    Ingests a batch of GPS points from the phone.
    We receive a batch because the phone saves battery by sending data every 5 mins.
    """
    now = datetime.now(timezone.utc)
    db_points = []
    
    for point in batch.points:
        lon, lat = point.location
        point_wkt = f"SRID=4326;POINT({lon} {lat})"

        db_point = models.GPSPoint(
            recorded_at=point.recorded_at,
            received_at=now,
            location=point_wkt,
            accuracy=point.accuracy,
            speed=point.speed,
            battery_level=point.battery_level
        )
        db_points.append(db_point)

    db.add_all(db_points)
    await db.commit()
    
    # After inserting points, update the daily_tracks table
    # This automatically creates a track for the day and updates the raw line
    # so we don't have to wait for a background job to do it before snapping
    import zoneinfo
    manila_tz = zoneinfo.ZoneInfo('Asia/Manila')
    affected_dates = list({point.recorded_at.astimezone(manila_tz).date() for point in batch.points})
    
    if affected_dates:
        update_track_query = text("""
            INSERT INTO daily_tracks (id, date, raw_line, point_count, total_distance_m)
            SELECT 
                gen_random_uuid(),
                DATE(recorded_at AT TIME ZONE 'Asia/Manila'),
                ST_MakeLine(location::geometry ORDER BY recorded_at) as raw_line,
                COUNT(*),
                ST_Length(ST_MakeLine(location::geometry ORDER BY recorded_at)::geography)
            FROM gps_points
            WHERE DATE(recorded_at AT TIME ZONE 'Asia/Manila') = ANY(:affected_dates)
            GROUP BY DATE(recorded_at AT TIME ZONE 'Asia/Manila')
            ON CONFLICT (date) DO UPDATE SET
                raw_line = EXCLUDED.raw_line,
                point_count = EXCLUDED.point_count,
                total_distance_m = EXCLUDED.total_distance_m,
                timeline_json = NULL;
        """)
        await db.execute(update_track_query, {"affected_dates": affected_dates})
        await db.commit()
    
    return {"message": f"Successfully ingested {len(db_points)} points."}
