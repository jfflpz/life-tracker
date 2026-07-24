import httpx
import time

def test_osrm(point_count):
    coords = []
    lon, lat = 121.0, 14.6
    for i in range(point_count):
        coords.append(f"{lon},{lat}")
        lon += 0.0001
        lat += 0.0001
        
    coords_str = ";".join(coords)
    url = f"http://localhost:5000/match/v1/driving/{coords_str}"
    params = {"radiuses": ";".join(["30"] * point_count), "overview": "full", "geometries": "geojson"}
    
    start = time.time()
    try:
        res = httpx.get(url, params=params)
        duration = time.time() - start
        
        if res.status_code == 200:
            print(f"[{point_count} points] OK - {duration:.3f}s")
        elif res.status_code == 414:
             print(f"[{point_count} points] 414 URI Too Long - {duration:.3f}s")
        else:
             print(f"[{point_count} points] {res.status_code} - {res.text[:100]} - {duration:.3f}s")
    except Exception as e:
        print(f"[{point_count} points] ERROR: {e}")

for count in [250, 500, 1000, 1500, 2000, 2500, 3000]:
    test_osrm(count)
