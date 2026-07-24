from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
import uuid

class GPSPointCreate(BaseModel):
    recorded_at: datetime
    location: List[float] = Field(..., min_items=2, max_items=2, description="[lon, lat]")
    accuracy: float
    speed: Optional[float] = None
    battery_level: Optional[int] = None

class GPSBatchCreate(BaseModel):
    points: List[GPSPointCreate]

class PinnedLocationCreate(BaseModel):
    label: str
    icon: Optional[str] = None
    location: List[float] = Field(..., description="[lon, lat]")
    radius_m: float = 100.0

class PinnedLocationResponse(PinnedLocationCreate):
    id: uuid.UUID

    class Config:
        from_attributes = True
