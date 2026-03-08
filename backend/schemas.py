from pydantic import BaseModel

class LocationUpdate(BaseModel):
    user_id: int
    lat: float
    lon: float

class FlashSaleRequest(BaseModel):
    restaurant_id: int
    food_item: str
    discount_price: float
    radius_meters: int