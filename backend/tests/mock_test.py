import asyncio
import json
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from backend.core.database import DATABASE_URL
from services.osrm import match_route

async def main():
    engine = create_async_engine(DATABASE_URL, echo=False)
    
    # 4 points exactly along Roxas Boulevard in Manila
    coords = [
        (120.9815, 14.5820), # Roxas Blvd near Rizal Park
        (120.9820, 14.5780),
        (120.9830, 14.5730),
        (120.9840, 14.5680)  # Roxas Blvd near Manila Baywalk
    ]
    
    # 1. Ask OSRM to snap them to the road network
    geometry = await match_route(coords)
    geometry_json_str = json.dumps(geometry)
    
    # 2. Save it back to the database
    async with engine.begin() as conn:
        update_query = text("UPDATE daily_tracks SET snapped_line = ST_GeomFromGeoJSON(:geojson) WHERE date = '2026-07-20'")
        await conn.execute(update_query, {"geojson": geometry_json_str})
        
        # Also let's just make sure the date is correctly targeted by inserting if missing
        insert_query = text("""
            INSERT INTO daily_tracks (id, date, raw_line, point_count, total_distance_m, snapped_line)
            VALUES (gen_random_uuid(), '2026-07-20', ST_GeomFromGeoJSON(:geojson), 4, 0.0, ST_GeomFromGeoJSON(:geojson))
            ON CONFLICT (date) DO UPDATE SET snapped_line = EXCLUDED.snapped_line;
        """)
        await conn.execute(insert_query, {"geojson": geometry_json_str})
        
    print("SUCCESS: Route matched and saved!")

asyncio.run(main())
