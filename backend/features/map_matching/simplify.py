import math
from typing import List, Tuple, Optional

def haversine(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    R = 6371000  # radius of Earth in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def point_line_distance(lon: float, lat: float, lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    # A simple cross-track distance using equirectangular approximation for small distances
    # For sub-km distances, Euclidean on projected coordinates is fine.
    # Convert everything to meters relative to (lon1, lat1)
    R = 6371000
    x = math.radians(lon - lon1) * math.cos(math.radians((lat + lat1) / 2)) * R
    y = math.radians(lat - lat1) * R
    
    x2 = math.radians(lon2 - lon1) * math.cos(math.radians((lat2 + lat1) / 2)) * R
    y2 = math.radians(lat2 - lat1) * R
    
    # Euclidean distance from (x,y) to line segment (0,0)-(x2,y2)
    line_len_sq = x2**2 + y2**2
    if line_len_sq == 0:
        return math.sqrt(x**2 + y**2)
        
    # Project point onto line, clamped to [0, 1]
    t = max(0, min(1, (x * x2 + y * y2) / line_len_sq))
    
    proj_x = t * x2
    proj_y = t * y2
    
    return math.sqrt((x - proj_x)**2 + (y - proj_y)**2)

def rdp_simplify(
    coords: List[Tuple[float, float]], 
    timestamps: Optional[List[int]], 
    epsilon: float
) -> Tuple[List[Tuple[float, float]], Optional[List[int]]]:
    """
    Ramer-Douglas-Peucker algorithm.
    epsilon is in meters.
    """
    if len(coords) < 3:
        return coords, timestamps

    dmax = 0.0
    index = 0
    end = len(coords) - 1

    for i in range(1, end):
        d = point_line_distance(
            coords[i][0], coords[i][1], 
            coords[0][0], coords[0][1], 
            coords[end][0], coords[end][1]
        )
        if d > dmax:
            index = i
            dmax = d

    if dmax > epsilon:
        # Recursive call
        left_coords, left_times = rdp_simplify(coords[:index+1], timestamps[:index+1] if timestamps else None, epsilon)
        right_coords, right_times = rdp_simplify(coords[index:], timestamps[index:] if timestamps else None, epsilon)

        # Merge
        result_coords = left_coords[:-1] + right_coords
        if timestamps:
            result_times = left_times[:-1] + right_times
        else:
            result_times = None
            
        return result_coords, result_times
    else:
        result_coords = [coords[0], coords[end]]
        if timestamps:
            result_times = [timestamps[0], timestamps[end]]
        else:
            result_times = None
        return result_coords, result_times

def preprocess_route(
    coords: List[Tuple[float, float]], 
    timestamps: Optional[List[int]]
) -> Tuple[List[Tuple[float, float]], Optional[List[int]]]:
    if not coords:
        return coords, timestamps
        
    # 1. Remove exact duplicates and stationary points (< 5 meters)
    filtered_coords = [coords[0]]
    filtered_times = [timestamps[0]] if timestamps else None
    
    for i in range(1, len(coords)):
        dist = haversine(
            filtered_coords[-1][0], filtered_coords[-1][1],
            coords[i][0], coords[i][1]
        )
        if dist > 5.0:  # must have moved at least 5 meters
            filtered_coords.append(coords[i])
            if timestamps:
                filtered_times.append(timestamps[i])
                
    # 2. RDP Simplification (epsilon = 10 meters)
    # This removes intermediate points along a straight line.
    simple_coords, simple_times = rdp_simplify(filtered_coords, filtered_times, 10.0)
    
    return simple_coords, simple_times
