from pydantic import BaseModel, Field

class LocationUpdate(BaseModel):
    user_id: int = Field(
        ..., 
        gt=0, 
        description="ID użytkownika musi być liczbą całkowitą większą od zera."
    )
    lat: float = Field(
        ..., 
        ge=-90.0, 
        le=90.0, 
        description="Szerokość geograficzna musi mieścić się w przedziale od -90.0 do 90.0."
    )
    lon: float = Field(
        ..., 
        ge=-180.0, 
        le=180.0, 
        description="Długość geograficzna musi mieścić się w przedziale od -180.0 do 180.0."
    )

class FlashSaleRequest(BaseModel):
    restaurant_id: int = Field(
        ..., 
        gt=0, 
        description="ID restauracji musi być liczbą całkowitą większą od zera."
    )
    food_item: str = Field(
        ..., 
        min_length=2, 
        max_length=100, 
        description="Nazwa produktu musi zawierać od 2 do 100 znaków."
    )
    discount_price: float = Field(
        ..., 
        ge=0.0, 
        description="Cena promocyjna nie może być wartością ujemną."
    )
    radius_meters: int = Field(
        ..., 
        gt=0, 
        le=20000, 
        description="Promień wyszukiwania musi być większy od 0 i nie większy niż 20 km."
    )
    duration_minutes: int = Field(
        ..., 
        gt=0, 
        le=1440, 
        description="Czas trwania promocji w minutach (max 24h)."
    )

class CancelSaleRequest(BaseModel):
    restaurant_id: int = Field(..., gt=0)
    sale_id: int = Field(..., gt=0)