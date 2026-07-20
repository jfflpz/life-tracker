import asyncio
import json
import httpx
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from database import DATABASE_URL

async def main():
    engine = create_async_engine(DATABASE_URL, echo=False)
    
    # 2 points on MacArthur Highway in Marilao
    start_lon, start_lat = 120.942, 14.762
    end_lon, end_lat = 120.952, 14.752
    
    url = f"http://localhost:5000/route/v1/driving/{start_lon},{start_lat};{end_lon},{end_lat}?geometries=geojson"
    
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        data = response.json()
        
        geometry = data["routes"][0]["geometry"]
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
        
    print("SUCCESS: Marilao route generated and saved!")

asyncio.run(main())
