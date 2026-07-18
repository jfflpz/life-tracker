import httpx
from typing import List, Tuple

OSRM_BASE_URL = "http://localhost:5000"

async def match_route(coordinates: List[Tuple[float, float]]) -> dict:
    """
    Sends raw GPS coordinates to OSRM's Map Matching API.
    coordinates: List of (longitude, latitude)
    Returns the snapped GeoJSON LineString geometry.
    """
    # OSRM expects coordinates in the format: lon,lat;lon,lat;...
    coords_string = ";".join([f"{lon},{lat}" for lon, lat in coordinates])
    
    # We ask OSRM for the full geometry in GeoJSON format
    url = f"{OSRM_BASE_URL}/match/v1/driving/{coords_string}"
    params = {
        "overview": "full",
        "geometries": "geojson",
        "tidy": "true" # Cleans up messy GPS clusters
    }
    
    # TODO: Make an async HTTP GET request using httpx to the url and params.
    # Check if response status is 200.
    # Parse the JSON response.
    # The road-snapped geometry is inside: response_data["matchings"][0]["geometry"]
    # Return that geometry dictionary!

    async with httpx.AsyncClient() as client:
        response = await client.get(url, params=params)
        if response.status_code != 200:
            raise Exception(f"OSRM request failed with status {response.status_code}: {response.text}")
        
        response_data = response.json()
        if "matchings" not in response_data or not response_data["matchings"]:
            raise Exception("No matchings found in OSRM response.")
        
        geometry = response_data["matchings"][0]["geometry"]
        return geometry
    
    pass
