# Life Tracker API Specification

## Base URL
`/api/v1`

---

## 1. Daily Track Summary
**Endpoint:** `GET /daily/summary/{year}/{month}`
**Description:** Fetches a lightweight summary of all recorded days within a specific month.
**Version:** 1

### Request Parameters
| Name  | In   | Type  | Description                |
|-------|------|-------|----------------------------|
| year  | path | int   | Year (e.g., 2026)          |
| month | path | int   | Month (1-12)               |

### Response
```json
{
  "version": 1,
  "year": 2026,
  "month": 7,
  "summary": {
    "active_days_count": 2,
    "total_points": 2105,
    "total_distance_m": 12500.5,
    "average_daily_distance_m": 6250.25,
    "moving_time_sec": 3600,
    "stationary_time_sec": 8400
  },
  "active_days": [
    {
      "date": "2026-07-20",
      "day_of_week": 1,
      "point_count": 1205,
      "distance_m": 5000.0,
      "has_route": true,
      "has_timeline": true,
      "moving_time_sec": 1200,
      "stationary_time_sec": 3600
    }
  ]
}
```

---

## 2. Daily Route Geometry
**Endpoint:** `GET /daily/{date}`
**Description:** Fetches the full map geometry (GeoJSON FeatureCollection) for a specific date.
**Version:** 1

### Request Parameters
| Name | In   | Type   | Description                |
|------|------|--------|----------------------------|
| date | path | string | ISO 8601 Date (YYYY-MM-DD) |

### Response
```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "id": "uuid",
        "date": "2026-07-20",
        "distance_m": 5000.0,
        "points": 1205
      },
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [120.942, 14.762],
          [120.952, 14.752]
        ]
      }
    }
  ]
}
```

---

## 3. Daily Timeline Events
**Endpoint:** `GET /daily/{date}/timeline`
**Description:** Fetches the chronological timeline of stops and movements for a given date.
**Version:** 1

### Request Parameters
| Name | In   | Type   | Description                |
|------|------|--------|----------------------------|
| date | path | string | ISO 8601 Date (YYYY-MM-DD) |

### Response
```json
{
  "metadata": {
    "version": 1,
    "date": "2026-07-20",
    "generated_at": "2026-07-24T12:00:00Z",
    "point_count": 1205
  },
  "summary": {
    "total_distance_m": 5000.0,
    "moving_time_sec": 1200,
    "stationary_time_sec": 3600
  },
  "events": [
    {
      "id": "md5hash",
      "type": "stop",
      "start_time": "2026-07-20T10:00:00+08:00",
      "end_time": "2026-07-20T11:00:00+08:00",
      "duration_sec": 3600,
      "location_name": "Home",
      "pin_id": "uuid",
      "lat": 14.762,
      "lon": 120.942
    },
    {
      "id": "md5hash2",
      "type": "moving",
      "start_time": "2026-07-20T11:00:00+08:00",
      "end_time": "2026-07-20T11:20:00+08:00",
      "duration_sec": 1200,
      "distance_m": 5000.0,
      "start_lat": 14.762,
      "start_lon": 120.942,
      "end_lat": 14.752,
      "end_lon": 120.952
    }
  ]
}
```
