from fastapi import APIRouter, HTTPException, Request
from schemas import LoginRequest, RegisterUserRequest, RegisterRestaurantRequest
import jwt
import os
from passlib.context import CryptContext

router = APIRouter(prefix="/api/auth", tags=["Auth"])
SECRET_KEY = os.getenv("JWT_SECRET", "gastro_radar_super_secret_123")

# Konfiguracja silnika szyfrującego hasła (Bcrypt)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

@router.post("/register/user")
async def register_user(data: RegisterUserRequest, request: Request):
    pool = request.app.state.db_pool
    async with pool.acquire() as conn:
        exists = await conn.fetchval("SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)", data.username)
        if exists:
            raise HTTPException(400, "Użytkownik o takiej nazwie już istnieje.")
        
        hashed_pw = get_password_hash(data.password)
        user_id = await conn.fetchval(
            "INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id",
            data.username, hashed_pw
        )
    return {"status": "success", "message": "Konto klienta utworzone pomyślnie.", "user_id": user_id}

@router.post("/register/restaurant")
async def register_restaurant(data: RegisterRestaurantRequest, request: Request):
    pool = request.app.state.db_pool
    async with pool.acquire() as conn:
        exists = await conn.fetchval("SELECT EXISTS(SELECT 1 FROM restaurants WHERE name = $1)", data.name)
        if exists:
            raise HTTPException(400, "Restauracja o takiej nazwie już istnieje.")
        
        hashed_pw = get_password_hash(data.password)
        # Przy rejestracji lokalu od razu przypisujemy jego fizyczną lokalizację GPS
        rest_id = await conn.fetchval(
            """INSERT INTO restaurants (name, password_hash, location) 
               VALUES ($1, $2, ST_SetSRID(ST_MakePoint($4, $3), 4326)) RETURNING id""",
            data.name, hashed_pw, data.lat, data.lon
        )
    return {"status": "success", "message": "Konto restauracji utworzone pomyślnie.", "restaurant_id": rest_id}

@router.post("/login")
async def login(data: LoginRequest, request: Request):
    pool = request.app.state.db_pool
    async with pool.acquire() as conn:
        if data.role == "user":
            record = await conn.fetchrow("SELECT id, password_hash FROM users WHERE username = $1", data.username)
        elif data.role == "restaurant":
            record = await conn.fetchrow("SELECT id, password_hash FROM restaurants WHERE name = $1", data.username)
        else:
            raise HTTPException(400, "Nieznana rola.")

        # Weryfikacja odszyfrowanego hasła
        if not record or not verify_password(data.password, record["password_hash"]):
            raise HTTPException(401, "Nieprawidłowa nazwa użytkownika lub hasło.")

        # Pakowanie potwierdzenia w podpisany Token JWT
        token = jwt.encode({"sub": str(record["id"]), "role": data.role}, SECRET_KEY, algorithm="HS256")
        return {"access_token": token, "token_type": "bearer", "id": record["id"]}