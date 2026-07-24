import requests
import datetime

today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
res = requests.post(f"http://127.0.0.1:8000/api/v1/snap/{today}")
print(res.status_code)
print(res.text)
