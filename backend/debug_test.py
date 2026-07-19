import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from database import DATABASE_URL
import schemas
import models
from routers.points import ingest_gps_batch
import datetime

async def main():
    engine = create_async_engine(DATABASE_URL, echo=False)
    AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    now = datetime.datetime.now(datetime.timezone.utc)
    batch = schemas.GPSBatchCreate(points=[
        schemas.GPSPointCreate(location=[120.9, 14.5], recorded_at=now, accuracy=10.0),
        schemas.GPSPointCreate(location=[120.9, 14.6], recorded_at=now, accuracy=10.0)
    ])
    
    async with AsyncSessionLocal() as db:
        try:
            res = await ingest_gps_batch(batch, db)
            print("SUCCESS:", res)
        except Exception as e:
            import traceback
            traceback.print_exc()

asyncio.run(main())
