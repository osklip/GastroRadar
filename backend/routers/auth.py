from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
import jwt
import os

router = APIRouter(prefix="/api/auth", tags=["Auth"])
SECRET_KEY = os.getenv("JWT_SECRET", "gastro_radar_super_secret_123")

class LoginRequest(BaseModel):
    id: int
    role: str

@router.post("/login")
async def login(data: LoginRequest, request: Request):
    pool = request.app.state.db_pool
    async with pool.acquire() as conn:
        if data.role == "user":
            exists = await conn.fetchval("SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)", data.id)
        elif data.role == "restaurant":
            exists = await conn.fetchval("SELECT EXISTS(SELECT 1 FROM restaurants WHERE id = $1)", data.id)
        else:
            raise HTTPException(400, "Nieznana rola.")

        if not exists:
            raise HTTPException(404, "Konto o podanym ID nie istnieje w bazie danych.")

        # Generowanie bezpiecznego tokenu JWT z rolą i ID
        token = jwt.encode({"sub": str(data.id), "role": data.role}, SECRET_KEY, algorithm="HS256")
        return {"access_token": token, "token_type": "bearer"}