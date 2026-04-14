from fastapi import APIRouter, HTTPException, Request, Depends, Query
from typing import Optional
from schemas import FlashSaleRequest, CancelSaleRequest
from auth_utils import get_current_token_payload
import logging

FCM_ENABLED = False
messaging = None

try:
    import firebase_admin
    from firebase_admin import messaging as fb_messaging
    if not firebase_admin._apps:
        # Wymaga ustawienia zmiennej środowiskowej GOOGLE_APPLICATION_CREDENTIALS w .env
        firebase_admin.initialize_app()
    messaging = fb_messaging
    FCM_ENABLED = True
except ImportError:
    logging.warning("firebase-admin nie jest zainstalowany. Powiadomienia push (FCM) będą ignorowane.")
except ValueError:
    logging.warning("Brak konfiguracji Firebase. Powiadomienia push (FCM) będą ignorowane.")

router = APIRouter(prefix="/api/restaurants", tags=["Restaurants"])

def get_restaurant_id_from_payload(payload: dict) -> int:
    """Funkcja pomocnicza weryfikująca istnienie ID dla Pylance"""
    sub = payload.get("sub")
    if sub is None:
        raise HTTPException(status_code=401, detail="Token JWT nie zawiera identyfikatora.")
    if payload.get("role") != "restaurant":
        raise HTTPException(status_code=403, detail="Wymagana rola restauracji.")
    
    return int(str(sub))

@router.post("/flash-sale")
async def trigger_flash_sale(
    sale: FlashSaleRequest, 
    request: Request, 
    payload: dict = Depends(get_current_token_payload)
):
    restaurant_id = get_restaurant_id_from_payload(payload)

    pool = request.app.state.db_pool
    async with pool.acquire() as connection:
        restaurant = await connection.fetchrow(
            "SELECT name, cuisine_type, ST_X(location) as lon, ST_Y(location) as lat FROM restaurants WHERE id = $1", 
            restaurant_id
        )
        if not restaurant:
            raise HTTPException(status_code=404, detail="Restauracja nie znaleziona.")

        query_find_users = """
            SELECT u.id, u.fcm_token FROM users u JOIN user_locations ul ON u.id = ul.user_id
            WHERE ST_DWithin(ul.location::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
        """
        nearby_users = await connection.fetch(query_find_users, restaurant['lon'], restaurant['lat'], sale.radius_meters)

        await connection.execute(
            """INSERT INTO flash_sales (restaurant_id, food_item, discount_price, radius_meters, expires_at)
               VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP + ($5 * INTERVAL '1 minute'))""",
            restaurant_id, sale.food_item, sale.discount_price, sale.radius_meters, sale.duration_minutes
        )

        notifications_sent = 0
        fcm_tokens_to_notify = []

        for user in nearby_users:
            uid = user['id']
            fcm_token = user['fcm_token']
            msg = f"Szybka akcja w {restaurant['name']}! {sale.food_item} za jedyne {sale.discount_price} PLN!"
            
            # Zapis do wewnętrznego inboksa
            await connection.execute("INSERT INTO pending_notifications (user_id, message) VALUES ($1, $2)", uid, msg)
            notifications_sent += 1

            if fcm_token:
                fcm_tokens_to_notify.append(fcm_token)

        # Wysłanie powiadomień Push via FCM (sprawdzenie uwzględnia teraz zabezpieczenie Pylance)
        if FCM_ENABLED and messaging is not None and fcm_tokens_to_notify:
            try:
                message = messaging.MulticastMessage(
                    notification=messaging.Notification(
                        title=f"GastroRadar - {restaurant['name']}",
                        body=f"{sale.food_item} za {sale.discount_price} PLN!"
                    ),
                    tokens=fcm_tokens_to_notify,
                )
                messaging.send_multicast(message)
            except Exception as e:
                logging.error(f"Błąd wysyłania powiadomień FCM: {e}")

    return {"status": "success", "users_notified_count": notifications_sent}


@router.get("/active-sales")
async def get_active_sales(
    request: Request, 
    cuisine: Optional[str] = Query(None, description="Filtruj po typie kuchni"),
    payload: dict = Depends(get_current_token_payload)
):
    pool = request.app.state.db_pool
    async with pool.acquire() as connection:
        
        base_query = """
            SELECT f.id, f.food_item, f.discount_price, f.radius_meters, f.expires_at, 
                   r.name as restaurant_name, r.cuisine_type
            FROM flash_sales f
            JOIN restaurants r ON f.restaurant_id = r.id
            WHERE f.expires_at > CURRENT_TIMESTAMP
        """
        
        if cuisine:
            rows = await connection.fetch(base_query + " AND r.cuisine_type = $1 ORDER BY f.expires_at ASC", cuisine)
        else:
            rows = await connection.fetch(base_query + " ORDER BY f.expires_at ASC")
        
        sales = [{
            "id": r["id"], 
            "restaurant_name": r["restaurant_name"],
            "cuisine_type": r["cuisine_type"],
            "food_item": r["food_item"], 
            "discount_price": float(r["discount_price"]),
            "radius_meters": r["radius_meters"], 
            "expires_at": r["expires_at"].isoformat()
        } for r in rows]
        
    return {"status": "success", "sales": sales}


@router.post("/cancel-sale")
async def cancel_flash_sale(data: CancelSaleRequest, request: Request, payload: dict = Depends(get_current_token_payload)):
    restaurant_id = get_restaurant_id_from_payload(payload)
    
    pool = request.app.state.db_pool
    async with pool.acquire() as connection:
        await connection.execute(
            "UPDATE flash_sales SET expires_at = CURRENT_TIMESTAMP WHERE id = $1 AND restaurant_id = $2",
            data.sale_id, restaurant_id
        )
    return {"status": "success"}