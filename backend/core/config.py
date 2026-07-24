import os                                                                                                                                      
from pydantic_settings import BaseSettings                                                                                                     
                                                                                                                                                
class Settings(BaseSettings):                                                                                                                  
    DATABASE_URL: str = os.getenv(                                                                                                             
        "DATABASE_URL",                                                                                                                        
        "postgresql://postgres:postgres@localhost:5432/life_tracker"                                                                           
    )                                                                                                                                          
                                                                                                                                                
    OSRM_BASE_URL: str = os.getenv(                                                                                                            
        "OSRM_BASE_URL",                                                                                                                       
        "http://localhost:5000"                                                                                                                
    )                                                                                                                                          
                                                                                                                                                
    class Config:                                                                                                                              
        env_file = ".env"

settings = Settings()
