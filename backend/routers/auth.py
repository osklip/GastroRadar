from fastapi import APIRouter, HTTPException, Request
from schemas import LoginRequest, RegisterUserRequest, RegisterRestaurantRequest
from auth_utils import verify_password, get_password_hash, create_access_token
import asyncpg

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

@router.post("/login")
async def login(data: LoginRequest, request: Request):
    pool = request.app.state.db_pool
    async with pool.acquire() as connection:
        if data.role == "user":
            record = await connection.fetchrow("SELECT id, password_hash FROM users WHERE username = $1", data.username)
        elif data.role == "restaurant":
            record = await connection.fetchrow("SELECT id, password_hash FROM restaurants WHERE name = $1", data.username)
        else:
            raise HTTPException(status_code=400, detail="Nieprawidłowa rola")

        if not record or not verify_password(data.password, record["password_hash"]):
            raise HTTPException(status_code=401, detail="Nieprawidłowe dane logowania")

        token_data = {"sub": str(record["id"]), "role": data.role}
        access_token = create_access_token(token_data)

        return {"access_token": access_token, "token_type": "bearer", "id": record["id"], "role": data.role}

@router.post("/register/user")
async def register_user(data: RegisterUserRequest, request: Request):
    pool = request.app.state.db_pool
    hashed_password = get_password_hash(data.password)

    async with pool.acquire() as connection:
        try:
            user_id = await connection.fetchval(
                "INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id",
                data.username, hashed_password
            )
            return {"status": "success", "user_id": user_id}
        except asyncpg.exceptions.UniqueViolationError:
            raise HTTPException(status_code=400, detail="Nazwa użytkownika jest już zajęta")

@router.post("/register/restaurant")
async def register_restaurant(data: RegisterRestaurantRequest, request: Request):
    pool = request.app.state.db_pool
    hashed_password = get_password_hash(data.password)

    async with pool.acquire() as connection:
        try:
            restaurant_id = await connection.fetchval(
                "INSERT INTO restaurants (name, password_hash, cuisine_type, location) VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($5, $4), 4326)) RETURNING id",
                data.name, hashed_password, data.cuisine_type, data.lat, data.lon
            )
            return {"status": "success", "restaurant_id": restaurant_id}
        except asyncpg.exceptions.UniqueViolationError:
            raise HTTPException(status_code=400, detail="Nazwa restauracji jest już zajęta")