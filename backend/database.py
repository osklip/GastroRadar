import os
import asyncpg
from contextlib import asynccontextmanager
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

async def init_db(pool):
    """Tworzy kompletną strukturę bazy danych przy uruchomieniu."""
    async with pool.acquire() as conn:
        # Rozszerzenie geograficzne
        await conn.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        
        # 1. Użytkownicy (Klienci)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL
            );
        """)
        
        # 2. Restauracje
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS restaurants (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                location GEOMETRY(Point, 4326) NOT NULL
            );
        """)
        
        # 3. Pozycje użytkowników
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS user_locations (
                user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                location GEOMETRY(Point, 4326) NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        
        # 4. Promocje
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS flash_sales (
                id SERIAL PRIMARY KEY,
                restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE CASCADE,
                food_item VARCHAR(100) NOT NULL,
                discount_price NUMERIC(5, 2) NOT NULL,
                radius_meters INTEGER NOT NULL,
                expires_at TIMESTAMP NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)

        # 5. Oczekujące powiadomienia
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS pending_notifications (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
                message TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)

@asynccontextmanager
async def lifespan(app: FastAPI):
    if not DATABASE_URL:
        raise ValueError("CRITICAL: Brak zmiennej DATABASE_URL. Sprawdź plik .env!")
    pool = await asyncpg.create_pool(DATABASE_URL)
    app.state.db_pool = pool
    await init_db(pool)
    yield
    if pool is not None:
        await pool.close()