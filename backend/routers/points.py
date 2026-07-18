from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone
import models, schemas
from database import get_db

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
    
    
    return {"message": f"Successfully ingested {len(db_points)} points."}
