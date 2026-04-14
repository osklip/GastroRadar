from pydantic import BaseModel, Field
from typing import Optional

class LocationUpdate(BaseModel):
    lat: float = Field(..., ge=-90.0, le=90.0)
    lon: float = Field(..., ge=-180.0, le=180.0)

class FlashSaleRequest(BaseModel):
    food_item: str = Field(..., min_length=2, max_length=100)
    discount_price: float = Field(..., ge=0.0)
    radius_meters: int = Field(..., gt=0, le=20000)
    duration_minutes: int = Field(..., gt=0, le=1440)

class CancelSaleRequest(BaseModel):
    sale_id: int = Field(..., gt=0)

class FCMTokenUpdate(BaseModel):
    fcm_token: str = Field(..., min_length=10)

# --- NOWE MODELE AUTORYZACJI ---

class LoginRequest(BaseModel):
    username: str
    password: str
    role: str

class RegisterUserRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)

class RegisterRestaurantRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    password: str = Field(..., min_length=6)
    cuisine_type: str = Field(..., min_length=2, max_length=50)
    lat: float = Field(..., ge=-90.0, le=90.0)
    lon: float = Field(..., ge=-180.0, le=180.0)