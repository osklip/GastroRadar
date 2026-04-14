from fastapi import APIRouter, HTTPException, Request, Depends
from schemas import LocationUpdate, FCMTokenUpdate
from auth_utils import get_current_token_payload

router = APIRouter(prefix="/api/users", tags=["Users"])

@router.post("/location")
async def update_location(data: LocationUpdate, request: Request, payload: dict = Depends(get_current_token_payload)):
    if payload.get("role") != "user":
        raise HTTPException(status_code=403, detail="Wymagana rola klienta.")
    
    user_id = int(str(payload.get("sub")))
    pool = request.app.state.db_pool
    
    async with pool.acquire() as conn:
        # ON CONFLICT eliminuje błąd przy ponownej aktualizacji lokalizacji istniejącego wiersza
        await conn.execute(
            """INSERT INTO user_locations (user_id, location) 
               VALUES ($1, ST_SetSRID(ST_MakePoint($3, $2), 4326))
               ON CONFLICT (user_id) DO UPDATE 
               SET location = EXCLUDED.location, updated_at = CURRENT_TIMESTAMP""",
            user_id, data.lat, data.lon
        )
    return {"status": "success"}

@router.post("/fcm-token")
async def update_fcm_token(data: FCMTokenUpdate, request: Request, payload: dict = Depends(get_current_token_payload)):
    if payload.get("role") != "user":
        raise HTTPException(status_code=403, detail="Wymagana rola klienta.")
    
    user_id = int(str(payload.get("sub")))
    pool = request.app.state.db_pool
    
    async with pool.acquire() as conn:
        await conn.execute("UPDATE users SET fcm_token = $1 WHERE id = $2", data.fcm_token, user_id)
        
    return {"status": "success"}