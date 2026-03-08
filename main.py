from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from contextlib import asynccontextmanager
import asyncpg
import uvicorn

DATABASE_URL = "postgresql://postgres:pashalol11@localhost:5432/gastroradar"

# Prosta makieta skrzynki powiadomień w pamięci serwera (user_id -> lista wiadomości)
PENDING_NOTIFICATIONS: dict[int, list[str]] = {}

@asynccontextmanager
async def lifespan(app: FastAPI):
    pool = await asyncpg.create_pool(DATABASE_URL)
    app.state.db_pool = pool
    yield
    if pool is not None:
        await pool.close()

app = FastAPI(
    title="GastroRadar API",
    description="Backend cienkiego klienta z obsługą PostGIS i systemem powiadomień",
    version="1.0.0",
    lifespan=lifespan
)

class LocationUpdate(BaseModel):
    user_id: int
    lat: float
    lon: float

class FlashSaleRequest(BaseModel):
    restaurant_id: int
    food_item: str
    discount_price: float
    radius_meters: int

@app.post("/api/users/location")
async def update_user_location(data: LocationUpdate, request: Request):
    """
    Telefon wysyła GPS. Serwer zapisuje go w bazie i sprawdza, czy są jakieś nowe alerty dla tego użytkownika.
    """
    query = """
        INSERT INTO user_locations (user_id, location, updated_at)
        VALUES ($1, ST_SetSRID(ST_MakePoint($3, $2), 4326), CURRENT_TIMESTAMP)
        ON CONFLICT (user_id) 
        DO UPDATE SET 
            location = ST_SetSRID(ST_MakePoint($3, $2), 4326),
            updated_at = CURRENT_TIMESTAMP;
    """
    
    pool = request.app.state.db_pool
    if pool is None:
        raise HTTPException(status_code=500, detail="Brak połączenia z bazą danych")

    async with pool.acquire() as connection:
        await connection.execute(query, data.user_id, data.lat, data.lon)
        
    # Sprawdzenie powiadomień dla użytkownika (Logika decyzyjna na serwerze)
    user_alerts = PENDING_NOTIFICATIONS.get(data.user_id, [])
    if user_alerts:
        # Czyścimy skrzynkę po odebraniu
        PENDING_NOTIFICATIONS[data.user_id] = []
        
    return {
        "status": "success", 
        "message": "Lokalizacja zaktualizowana.",
        "alerts": user_alerts  # Zwracamy listę nowych powiadomień do telefonu
    }

@app.post("/api/restaurants/flash-sale")
async def trigger_flash_sale(sale: FlashSaleRequest, request: Request):
    """
    Wyszukuje użytkowników w promieniu i dodaje im powiadomienia do kolejki oczekującej.
    """
    pool = request.app.state.db_pool
    if pool is None:
        raise HTTPException(status_code=500, detail="Brak połączenia z bazą danych")

    async with pool.acquire() as connection:
        restaurant = await connection.fetchrow(
            "SELECT name, ST_X(location) as lon, ST_Y(location) as lat FROM restaurants WHERE id = $1", 
            sale.restaurant_id
        )
        
        if not restaurant:
            raise HTTPException(status_code=404, detail="Restauracja nie znaleziona.")

        query_find_users = """
            SELECT u.id 
            FROM users u
            JOIN user_locations ul ON u.id = ul.user_id
            WHERE ST_DWithin(
                ul.location::geography, 
                ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 
                $3
            )
        """
        
        nearby_users = await connection.fetch(
            query_find_users, 
            restaurant['lon'], 
            restaurant['lat'], 
            sale.radius_meters
        )

        await connection.execute(
            """
            INSERT INTO flash_sales (restaurant_id, food_item, discount_price, radius_meters, expires_at)
            VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP + INTERVAL '30 minutes')
            """,
            sale.restaurant_id, sale.food_item, sale.discount_price, sale.radius_meters
        )

    # Kolejkowanie powiadomień w pamięci
    notifications_sent = 0
    for user in nearby_users:
        uid = user['id']
        msg = f"Szybka akcja w {restaurant['name']}! {sale.food_item} za jedyne {sale.discount_price} PLN!"
        
        if uid not in PENDING_NOTIFICATIONS:
            PENDING_NOTIFICATIONS[uid] = []
        PENDING_NOTIFICATIONS[uid].append(msg)
        notifications_sent += 1

    return {
        "status": "success", 
        "users_notified_count": notifications_sent
    }

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)