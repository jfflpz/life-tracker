import asyncio
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_summary():
    response = client.get("/api/v1/daily/summary/2026/07")
    print(response.status_code)
    print(response.json())

if __name__ == "__main__":
    test_summary()
