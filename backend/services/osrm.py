import httpx
from typing import List, Tuple

OSRM_BASE_URL = "http://localhost:5000"

async def match_route(coordinates: List[Tuple[float, float]]) -> dict:
    """
    Sends raw GPS coordinates to OSRM's Map Matching API.
    coordinates: List of (longitude, latitude)
    Returns the snapped GeoJSON LineString geometry.
    """
    coords_string = ";".join([f"{lon},{lat}" for lon, lat in coordinates])
    
    url = f"{OSRM_BASE_URL}/route/v1/driving/{coords_string}"
    params = {
        "overview": "full",
        "geometries": "geojson"
    }
    

    async with httpx.AsyncClient() as client:
        response = await client.get(url, params=params)
        if response.status_code != 200:
            raise Exception(f"OSRM request failed with status {response.status_code}: {response.text}")
        
        response_data = response.json()
        if "routes" not in response_data or not response_data["routes"]:
            raise Exception("No route found in OSRM response.")
        
        geometry = response_data["routes"][0]["geometry"]
        return geometry
