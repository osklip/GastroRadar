from fastapi import APIRouter, HTTPException, Request
from schemas import FlashSaleRequest

router = APIRouter(prefix="/api/restaurants", tags=["Restaurants"])

@router.post("/flash-sale")
async def trigger_flash_sale(sale: FlashSaleRequest, request: Request):
    """
    Wyszukuje użytkowników w promieniu, zapisuje promocję i wysyła im powiadomienia (zapis do bazy).
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

        # Trwałe zapisywanie powiadomień w bazie danych
        notifications_sent = 0
        for user in nearby_users:
            uid = user['id']
            msg = f"Szybka akcja w {restaurant['name']}! {sale.food_item} za jedyne {sale.discount_price} PLN!"
            
            await connection.execute(
                "INSERT INTO pending_notifications (user_id, message) VALUES ($1, $2)",
                uid, msg
            )
            notifications_sent += 1

    return {
        "status": "success", 
        "users_notified_count": notifications_sent
    }