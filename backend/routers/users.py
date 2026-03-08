from fastapi import APIRouter, HTTPException, Request, Depends
from schemas import LocationUpdate
from auth_utils import get_current_token_payload

router = APIRouter(prefix="/api/users", tags=["Users"])

@router.post("/location")
async def update_user_location(
    data: LocationUpdate, 
    request: Request, 
    payload: dict = Depends(get_current_token_payload)
):
    # Wyciągamy 'sub' z weryfikacją obecności dla statycznego typowania (Pylance fix)
    sub = payload.get("sub")
    if not sub:
        raise HTTPException(status_code=401, detail="Token JWT nie zawiera identyfikatora użytkownika.")
    
    user_id = int(sub)
    
    if payload.get("role") != "user":
        raise HTTPException(status_code=403, detail="Odmowa dostępu. Wymagana rola klienta.")

    pool = request.app.state.db_pool
    async with pool.acquire() as connection:
        query_update_loc = """
            INSERT INTO user_locations (user_id, location, updated_at)
            VALUES ($1, ST_SetSRID(ST_MakePoint($3, $2), 4326), CURRENT_TIMESTAMP)
            ON CONFLICT (user_id) 
            DO UPDATE SET location = ST_SetSRID(ST_MakePoint($3, $2), 4326), updated_at = CURRENT_TIMESTAMP;
        """
        await connection.execute(query_update_loc, user_id, data.lat, data.lon)
        
        query_active_deals = """
            SELECT r.name as restaurant_name, ST_Y(r.location::geometry) as lat, ST_X(r.location::geometry) as lon,
                   fs.food_item, fs.discount_price, ST_Distance(ul.location::geography, r.location::geography) as distance_meters
            FROM flash_sales fs
            JOIN restaurants r ON fs.restaurant_id = r.id
            JOIN user_locations ul ON ul.user_id = $1
            WHERE fs.expires_at > CURRENT_TIMESTAMP AND ST_DWithin(ul.location::geography, r.location::geography, fs.radius_meters)
            ORDER BY distance_meters ASC;
        """
        rows = await connection.fetch(query_active_deals, user_id)
        nearby_deals = [{"restaurant": r["restaurant_name"], "lat": float(r["lat"]), "lon": float(r["lon"]),
                         "item": r["food_item"], "price": float(r["discount_price"]), "distance": int(r["distance_meters"])} for r in rows]
        
        alerts_records = await connection.fetch("SELECT message FROM pending_notifications WHERE user_id = $1", user_id)
        user_alerts = [record['message'] for record in alerts_records]

        if user_alerts:
            await connection.execute("DELETE FROM pending_notifications WHERE user_id = $1", user_id)
        
    return {"status": "success", "alerts": user_alerts, "deals": nearby_deals}