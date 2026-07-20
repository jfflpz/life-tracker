import asyncio
import json
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from database import DATABASE_URL
from services.osrm import match_route

async def main():
    engine = create_async_engine(DATABASE_URL, echo=False)
    
    # The 4 arbitrary points I used
    coords = [
        (120.9450, 14.7550),
        (120.9480, 14.7578),
        (120.9500, 14.7600),
        (120.9550, 14.7650)
    ]
    
    # 1. Ask OSRM to snap them to the road network
    geometry = await match_route(coords)
    geometry_json_str = json.dumps(geometry)
    
    # 2. Save it back to the database
    async with engine.begin() as conn:
        update_query = text("UPDATE daily_tracks SET snapped_line = ST_GeomFromGeoJSON(:geojson) WHERE date = '2026-07-19'")
        await conn.execute(update_query, {"geojson": geometry_json_str})

asyncio.run(main())
