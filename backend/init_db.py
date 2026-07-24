import asyncio
from backend.core.database import engine, Base
import backend.features.tracking.models as models

async def init_db():
    async with engine.begin() as conn:
        print("Creating tables...")
        await conn.run_sync(Base.metadata.create_all)
        print("Tables created successfully!")

if __name__ == "__main__":
    asyncio.run(init_db())
