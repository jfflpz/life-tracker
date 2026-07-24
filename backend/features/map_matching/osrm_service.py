import httpx
import asyncio
import logging
from typing import List, Tuple, Optional
from core.config import settings
from features.map_matching.simplify import preprocess_route

OSRM_BASE_URL = settings.OSRM_BASE_URL
OSRM_MAX_COORDS = 500

logger = logging.getLogger(__name__)

async def match_route(
    coordinates: List[Tuple[float, float]],
    timestamps: Optional[List[int]] = None,
) -> dict:
    """
    Uses OSRM's Map Matching API (/match) instead of the Route API.
    
    /route calculates the SHORTEST route between waypoints — it invents detours.
    /match finds the roads you ACTUALLY traveled on, using a Hidden Markov Model
    that considers GPS noise, timing, and road connectivity.
    
    coordinates: List of (longitude, latitude)
    timestamps:  List of Unix epoch seconds (same length as coordinates)
    Returns the matched GeoJSON LineString geometry.
    """
    # 1. Preprocess: remove duplicates, stationary points, and simplify with RDP
    coords_pre, times_pre = preprocess_route(coordinates, timestamps)

    # 2. Hard limit downsample if still too large
    if len(coords_pre) > OSRM_MAX_COORDS:
        logger.warning(f"Route still has {len(coords_pre)} points after RDP. Hard downsampling to {OSRM_MAX_COORDS}.")
        coords_pre, times_pre = _downsample_with_timestamps(
            coords_pre, times_pre, OSRM_MAX_COORDS
        )

    coords_string = ";".join([f"{lon},{lat}" for lon, lat in coords_pre])

    url = f"{OSRM_BASE_URL}/match/v1/driving/{coords_string}"
    params = {
        "overview": "full",
        "geometries": "geojson",
        "gaps": "ignore", # Route along roads even if there are gaps, so lines never cross buildings
        "tidy": "true" # Clean up messy GPS clusters
    }

    if times_pre and len(times_pre) == len(coords_pre):
        params["timestamps"] = ";".join(str(t) for t in times_pre)

    params["radiuses"] = ";".join(["30"] * len(coords_pre))

    max_retries = 3
    base_delay = 2.0
    
    async with httpx.AsyncClient() as client:
        for attempt in range(max_retries):
            try:
                response = await client.get(url, params=params, timeout=30.0)
                
                if response.status_code != 200:
                    # Not a transient error (e.g. 400 Bad Request, no match), don't retry
                    raise Exception(
                        f"OSRM match request failed with status {response.status_code}: {response.text}"
                    )

                response_data = response.json()

                if "matchings" not in response_data or not response_data["matchings"]:
                    raise Exception("No matching route found in OSRM response.")

                all_coords = []
                for matching in response_data["matchings"]:
                    geom = matching["geometry"]
                    all_coords.extend(geom["coordinates"])

                return {"type": "LineString", "coordinates": all_coords}
                
            except (httpx.RequestError, httpx.TimeoutException) as e:
                # Transient network errors
                if attempt == max_retries - 1:
                    raise Exception(f"OSRM connection failed after {max_retries} attempts: {str(e)}")
                
                await asyncio.sleep(base_delay * (2 ** attempt))
            
        raise Exception("OSRM request failed.")


def _downsample_with_timestamps(
    coords: List[Tuple[float, float]],
    timestamps: Optional[List[int]],
    max_points: int,
) -> Tuple[List[Tuple[float, float]], Optional[List[int]]]:
    """
    Evenly sample `max_points` from the coordinate list,
    always keeping the first and last point for route accuracy.
    Also downsamples the corresponding timestamps.
    """
    if len(coords) <= max_points:
        return coords, timestamps

    indices = [0]
    step = (len(coords) - 1) / (max_points - 1)
    for i in range(1, max_points - 1):
        idx = int(round(i * step))
        indices.append(idx)
    indices.append(len(coords) - 1)

    sampled_coords = [coords[i] for i in indices]
    sampled_timestamps = [timestamps[i] for i in indices] if timestamps else None

    return sampled_coords, sampled_timestamps
