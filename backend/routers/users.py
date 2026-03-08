from fastapi import APIRouter, HTTPException, Request
from schemas import LocationUpdate

router = APIRouter(prefix="/api/users", tags=["Users"])

@router.post("/location")
async def update_user_location(data: LocationUpdate, request: Request):
    """
    Telefon wysyła GPS. Serwer waliduje istnienie użytkownika, aktualizuje pozycję, 
    sprawdza bazę w poszukiwaniu nowych alertów oraz aktywnych okazji w okolicy 
    (wraz ze współrzędnymi do nawigacji).
    """
    pool = request.app.state.db_pool
    if pool is None:
        raise HTTPException(status_code=500, detail="Brak połączenia z bazą danych")

    async with pool.acquire() as connection:
        # 1. Sprawdzenie, czy użytkownik istnieje w bazie
        user_exists = await connection.fetchval(
            "SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)", 
            data.user_id
        )
        if not user_exists:
            raise HTTPException(status_code=404, detail="Użytkownik o podanym ID nie istnieje.")

        # 2. Zapisz/zaktualizuj pozycję użytkownika
        query_update_loc = """
            INSERT INTO user_locations (user_id, location, updated_at)
            VALUES ($1, ST_SetSRID(ST_MakePoint($3, $2), 4326), CURRENT_TIMESTAMP)
            ON CONFLICT (user_id) 
            DO UPDATE SET 
                location = ST_SetSRID(ST_MakePoint($3, $2), 4326),
                updated_at = CURRENT_TIMESTAMP;
        """
        await connection.execute(query_update_loc, data.user_id, data.lat, data.lon)
        
        # 3. Pobierz trwające promocje (TERAZ Z DODATKIEM LAT i LON)
        query_active_deals = """
            SELECT 
                r.name as restaurant_name,
                ST_Y(r.location::geometry) as lat,
                ST_X(r.location::geometry) as lon,
                fs.food_item,
                fs.discount_price,
                ST_Distance(ul.location::geography, r.location::geography) as distance_meters
            FROM flash_sales fs
            JOIN restaurants r ON fs.restaurant_id = r.id
            JOIN user_locations ul ON ul.user_id = $1
            WHERE fs.expires_at > CURRENT_TIMESTAMP
              AND ST_DWithin(ul.location::geography, r.location::geography, fs.radius_meters)
            ORDER BY distance_meters ASC;
        """
        rows = await connection.fetch(query_active_deals, data.user_id)
        
        nearby_deals = [
            {
                "restaurant": r["restaurant_name"],
                "lat": float(r["lat"]),
                "lon": float(r["lon"]),
                "item": r["food_item"],
                "price": float(r["discount_price"]),
                "distance": int(r["distance_meters"])
            } for r in rows
        ]
        
        # 4. Sprawdzenie jednorazowych powiadomień
        alerts_records = await connection.fetch(
            "SELECT message FROM pending_notifications WHERE user_id = $1",
            data.user_id
        )
        user_alerts = [record['message'] for record in alerts_records]

        # 5. Wyczyść odebrane powiadomienia
        if user_alerts:
            await connection.execute(
                "DELETE FROM pending_notifications WHERE user_id = $1",
                data.user_id
            )
        
    return {
        "status": "success", 
        "message": "Lokalizacja zaktualizowana.",
        "alerts": user_alerts,
        "deals": nearby_deals
    }