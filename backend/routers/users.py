from fastapi import APIRouter, HTTPException, Request, Depends
from schemas import LocationUpdate, FCMTokenUpdate, ClaimRequest
from auth_utils import get_current_token_payload
import asyncpg

router = APIRouter(prefix="/api/users", tags=["Users"])

@router.post("/location")
async def update_location(data: LocationUpdate, request: Request, payload: dict = Depends(get_current_token_payload)):
    if payload.get("role") != "user":
        raise HTTPException(status_code=403, detail="Wymagana rola klienta.")
    
    user_id = int(str(payload.get("sub")))
    pool = request.app.state.db_pool
    
    async with pool.acquire() as conn:
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

@router.post("/claim-coupon")
async def claim_coupon(data: ClaimRequest, request: Request, payload: dict = Depends(get_current_token_payload)):
    if payload.get("role") != "user":
        raise HTTPException(status_code=403, detail="Wymagana rola klienta.")
        
    user_id = int(str(payload.get("sub")))
    pool = request.app.state.db_pool
    
    async with pool.acquire() as conn:
        try:
            inserted_id = await conn.fetchval("""
                INSERT INTO sale_claims (user_id, sale_id)
                SELECT $1, $2
                WHERE 
                    (SELECT expires_at FROM flash_sales WHERE id = $2) > CURRENT_TIMESTAMP
                    AND
                    (SELECT COUNT(*) FROM sale_claims WHERE sale_id = $2) < 
                    (SELECT max_claims FROM flash_sales WHERE id = $2)
                RETURNING id;
            """, user_id, data.sale_id)
            
            if not inserted_id:
                sale_status = await conn.fetchrow("SELECT expires_at, max_claims, (SELECT COUNT(*) FROM sale_claims WHERE sale_id = $1) as current FROM flash_sales WHERE id = $1", data.sale_id)
                if not sale_status:
                    raise HTTPException(404, "Oferta nie istnieje.")
                if sale_status['current'] >= sale_status['max_claims']:
                    raise HTTPException(400, "Wyczerpano limit kuponów dla tej promocji.")
                raise HTTPException(400, "Promocja już się zakończyła.")
                
        except asyncpg.exceptions.UniqueViolationError:
            pass
            
        code = await conn.fetchval("SELECT redemption_code FROM flash_sales WHERE id = $1", data.sale_id)
        return {"status": "success", "code": code}

@router.get("/my-coupons")
async def get_my_coupons(request: Request, payload: dict = Depends(get_current_token_payload)):
    if payload.get("role") != "user":
        raise HTTPException(status_code=403, detail="Wymagana rola klienta.")
        
    user_id = int(str(payload.get("sub")))
    pool = request.app.state.db_pool
    async with pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT f.id, f.food_item, f.discount_price, f.redemption_code, f.expires_at,
                   r.name as restaurant_name, r.cuisine_type, ST_X(r.location) as lon, ST_Y(r.location) as lat
            FROM sale_claims sc
            JOIN flash_sales f ON sc.sale_id = f.id
            JOIN restaurants r ON f.restaurant_id = r.id
            WHERE sc.user_id = $1 AND f.expires_at > CURRENT_TIMESTAMP - INTERVAL '6 hours'
            ORDER BY sc.claimed_at DESC
        """, user_id)
        
        coupons = [dict(r) for r in rows]
        for c in coupons:
            c['expires_at'] = c['expires_at'].isoformat()
            
        return {"status": "success", "coupons": coupons}