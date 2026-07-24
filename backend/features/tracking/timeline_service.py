import math
import json
from datetime import date, datetime, timedelta
from typing import List, Dict, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from features.tracking.models import DailyTrack, PinnedLocation

def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371000  # radius of Earth in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2)**2 + \
        math.cos(phi1) * math.cos(phi2) * \
        math.sin(delta_lambda / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

class TimelineService:
    def __init__(self, db: AsyncSession):
        self.db = db
        # Configurable thresholds
        self.stop_distance_threshold_m = 50.0  # Must stay within 50 meters
        self.stop_duration_threshold_sec = 300.0  # For at least 5 minutes

    async def get_timeline_for_date(self, target_date: date) -> Dict[str, Any]:
        # 1. Check if we already have a cached timeline_json for this date
        check_cache_query = text("""
            SELECT timeline_json 
            FROM daily_tracks 
            WHERE date = :target_date
        """)
        result = await self.db.execute(check_cache_query, {"target_date": target_date})
        row = result.fetchone()
        
        if row and row.timeline_json is not None:
            return row.timeline_json

        # 2. If not cached, calculate it. First, load all pins for matching
        pins_query = text("SELECT id, label, ST_Y(location::geometry) as lat, ST_X(location::geometry) as lon, radius_m FROM pinned_locations")
        pins_result = await self.db.execute(pins_query)
        pins = []
        for p in pins_result.fetchall():
            pins.append({
                "id": str(p.id),
                "label": p.label,
                "lat": p.lat,
                "lon": p.lon,
                "radius_m": p.radius_m
            })

        # 3. Load all GPS points for the day
        points_query = text("""
            SELECT 
                recorded_at AT TIME ZONE 'Asia/Manila' as recorded_at,
                ST_Y(location::geometry) as lat,
                ST_X(location::geometry) as lon
            FROM gps_points
            WHERE DATE(recorded_at AT TIME ZONE 'Asia/Manila') = :target_date
            ORDER BY recorded_at ASC
        """)
        points_result = await self.db.execute(points_query, {"target_date": target_date})
        points = points_result.fetchall()

        if not points:
            return self._empty_timeline(target_date)

        # 4. Generate events (Stops and Moving)
        events = []
        i = 0
        n = len(points)
        
        while i < n:
            start_point = points[i]
            j = i + 1
            
            # Find how far we can expand the stop
            while j < n:
                dist = haversine(start_point.lat, start_point.lon, points[j].lat, points[j].lon)
                if dist > self.stop_distance_threshold_m:
                    break
                j += 1
            
            end_idx = j - 1
            end_point = points[end_idx]
            duration_sec = (end_point.recorded_at - start_point.recorded_at).total_seconds()
            
            if duration_sec >= self.stop_duration_threshold_sec:
                # This is a STOP event
                # Match with pins
                location_name = "Unknown Stop"
                pin_id = None
                for pin in pins:
                    dist_to_pin = haversine(start_point.lat, start_point.lon, pin["lat"], pin["lon"])
                    if dist_to_pin <= pin["radius_m"]:
                        location_name = pin["label"]
                        pin_id = pin["id"]
                        break
                
                events.append({
                    "type": "stop",
                    "start_time": start_point.recorded_at.isoformat(),
                    "end_time": end_point.recorded_at.isoformat(),
                    "duration_sec": int(duration_sec),
                    "location_name": location_name,
                    "pin_id": pin_id,
                    "lat": start_point.lat,
                    "lon": start_point.lon
                })
                i = end_idx + 1 # advance past the stop
            else:
                # If it's not a stop, we don't immediately know how long the moving segment is.
                # A moving segment continues until the NEXT stop or the end of the points.
                # So we just advance i by 1. We will merge moving segments later.
                i += 1

        # 5. Fill in the gaps with MOVING events
        final_events = []
        last_time = points[0].recorded_at
        last_lat, last_lon = points[0].lat, points[0].lon
        
        for stop in events:
            stop_start = datetime.fromisoformat(stop["start_time"])
            
            # If there's a time gap before this stop, it's a moving event
            if stop_start > last_time:
                duration = (stop_start - last_time).total_seconds()
                # Approximate distance for the moving segment
                # (A real implementation might sum up the distances of points inside this window)
                # We'll just calculate straight line for now, or we can calculate actual distance by summing.
                # Let's do a simple sum for the points in this time window.
                dist = sum(
                    haversine(points[k].lat, points[k].lon, points[k+1].lat, points[k+1].lon)
                    for k in range(n-1)
                    if last_time <= points[k].recorded_at < stop_start
                )
                
                if duration > 0:
                    final_events.append({
                        "type": "moving",
                        "start_time": last_time.isoformat(),
                        "end_time": stop_start.isoformat(),
                        "duration_sec": int(duration),
                        "distance_m": dist,
                        "start_lat": last_lat,
                        "start_lon": last_lon,
                        "end_lat": stop["lat"],
                        "end_lon": stop["lon"]
                    })
            
            final_events.append(stop)
            last_time = datetime.fromisoformat(stop["end_time"])
            last_lat, last_lon = stop["lat"], stop["lon"]

        # Handle moving event at the end of the day if needed
        end_time = points[-1].recorded_at
        if end_time > last_time:
            duration = (end_time - last_time).total_seconds()
            dist = sum(
                haversine(points[k].lat, points[k].lon, points[k+1].lat, points[k+1].lon)
                for k in range(n-1)
                if last_time <= points[k].recorded_at < end_time
            )
            if duration > 0:
                final_events.append({
                    "type": "moving",
                    "start_time": last_time.isoformat(),
                    "end_time": end_time.isoformat(),
                    "duration_sec": int(duration),
                    "distance_m": dist,
                    "start_lat": last_lat,
                    "start_lon": last_lon,
                    "end_lat": points[-1].lat,
                    "end_lon": points[-1].lon
                })

        import hashlib
        for idx, event in enumerate(final_events):
            # Create a stable ID based on date, index, type, and start time
            stable_string = f"{target_date}_{idx}_{event['type']}_{event['start_time']}"
            event["id"] = hashlib.md5(stable_string.encode()).hexdigest()

        # 6. Calculate summary statistics
        total_moving_sec = sum(e["duration_sec"] for e in final_events if e["type"] == "moving")
        total_stationary_sec = sum(e["duration_sec"] for e in final_events if e["type"] == "stop")
        total_distance_m = sum(e.get("distance_m", 0) for e in final_events if e["type"] == "moving")
        
        timeline_response = {
            "metadata": {
                "version": 1,
                "date": str(target_date),
                "generated_at": datetime.utcnow().isoformat(),
                "point_count": len(points)
            },
            "summary": {
                "total_distance_m": total_distance_m,
                "moving_time_sec": total_moving_sec,
                "stationary_time_sec": total_stationary_sec
            },
            "events": final_events
        }

        # 7. Save to cache
        update_cache_query = text("""
            UPDATE daily_tracks 
            SET timeline_json = :timeline_json 
            WHERE date = :target_date
        """)
        # We need to convert it to a JSON string for JSONB insertion in asyncpg
        import json
        await self.db.execute(update_cache_query, {
            "timeline_json": json.dumps(timeline_response),
            "target_date": target_date
        })
        await self.db.commit()

        return timeline_response

    def _empty_timeline(self, target_date: date) -> Dict[str, Any]:
        return {
            "metadata": {
                "version": 1,
                "date": str(target_date),
                "generated_at": datetime.utcnow().isoformat(),
                "point_count": 0
            },
            "summary": {
                "total_distance_m": 0,
                "moving_time_sec": 0,
                "stationary_time_sec": 0
            },
            "events": []
        }
