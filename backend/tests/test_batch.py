import requests
import datetime

now = datetime.datetime.now(datetime.timezone.utc).isoformat()
payload = {
    "points": [
        {
            "location": [120.9842, 14.5995],
            "recorded_at": now,
            "accuracy": 10.0
        },
        {
            "location": [120.9843, 14.5996],
            "recorded_at": now,
            "accuracy": 10.0
        }
    ]
}

response = requests.post("http://127.0.0.1:8000/api/v1/points/batch", json=payload)
print(response.status_code)
print(response.text)
