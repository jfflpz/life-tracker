from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import points, daily, pins, snap

app = FastAPI(title="Life Tracker API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(points.router, prefix="/api/v1")
app.include_router(daily.router, prefix="/api/v1")
app.include_router(pins.router, prefix="/api/v1")
app.include_router(snap.router, prefix="/api/v1")

@app.get("/")
def read_root():
    return {"status": "Life Tracker API is running"}
