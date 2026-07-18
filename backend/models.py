import uuid                                                                                                                                    
from sqlalchemy import Column, String, Float, DateTime, Integer, Date                                                                          
from sqlalchemy.dialects.postgresql import UUID                                                                                                
from geoalchemy2 import Geometry                                                                                                               
from database import Base                                                                                                                      
                                                                                                                                                
class GPSPoint(Base):                                                                                                                          
    __tablename__ = "gps_points"                                                                                                               
                                                                                                                                                
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)                                                                      
                                                                                                                                                                                                                                       
    recorded_at = Column(DateTime(timezone=True), index=True, nullable=False)                                                                  
    received_at = Column(DateTime(timezone=True), nullable=False)                                                                              
                                                                                                                                                
    location = Column(Geometry("POINT", srid=4326), nullable=False)                                                                            
                                                                                                                                                                                                                                                               
    accuracy = Column(Float, nullable=False)                                                                          
    speed = Column(Float, nullable=True)                                                                              
    battery_level = Column(Integer, nullable=True)                                                                          
                                                                                                                                                
class DailyTrack(Base):                                                                                                                        
    __tablename__ = "daily_tracks"                                                                                                             
                                                                                                                                                
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)                                                                      
    date = Column(Date, unique=True, index=True, nullable=False)
    
    raw_line = Column(Geometry("LINESTRING", srid=4326), nullable=False)
    
    snapped_line = Column(Geometry("LINESTRING", srid=4326),nullable=True)
    
    total_distance_m = Column(Float, default=0.0)
    point_count = Column(Integer, default=0)

class PinnedLocation(Base):
    __tablename__ = "pinned_locations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    label = Column(String, nullable=False)
    icon = Column(String, nullable=True)
    
    location = Column(Geometry("POINT", srid=4326), nullable=False)
    
    radius_m = Column(Float, default=100.0)
