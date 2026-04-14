import os
import asyncpg
from contextlib import asynccontextmanager
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

async def init_db(pool):
    """Tworzy kompletną strukturę bazy danych z obsługą kuponów i limitów."""
    async with pool.acquire() as conn:
        await conn.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                fcm_token VARCHAR(255)
            );
        """)
        
        try:
            await conn.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(255);")
        except asyncpg.exceptions.DuplicateColumnError:
            pass
        
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS restaurants (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                cuisine_type VARCHAR(50),
                location GEOMETRY(Point, 4326) NOT NULL
            );
        """)

        try:
            await conn.execute("ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS cuisine_type VARCHAR(50);")
        except asyncpg.exceptions.DuplicateColumnError:
            pass
        
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS flash_sales (
                id SERIAL PRIMARY KEY,
                restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE CASCADE,
                food_item VARCHAR(100) NOT NULL,
                discount_price NUMERIC(5, 2) NOT NULL,
                radius_meters INTEGER NOT NULL,
                expires_at TIMESTAMP NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                redemption_code VARCHAR(4) NOT NULL DEFAULT '0000',
                max_claims INTEGER NOT NULL DEFAULT 50
            );
        """)

        # Zabezpieczenie dla bazy danych utworzonej we wcześniejszych krokach
        try:
            await conn.execute("ALTER TABLE flash_sales ADD COLUMN IF NOT EXISTS redemption_code VARCHAR(4) NOT NULL DEFAULT '0000';")
            await conn.execute("ALTER TABLE flash_sales ADD COLUMN IF NOT EXISTS max_claims INTEGER NOT NULL DEFAULT 50;")
        except asyncpg.exceptions.DuplicateColumnError:
            pass

        await conn.execute("""
            CREATE TABLE IF NOT EXISTS sale_claims (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
                sale_id INTEGER REFERENCES flash_sales(id) ON DELETE CASCADE,
                claimed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, sale_id)
            );
        """)
        
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS user_locations (
                user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                location GEOMETRY(Point, 4326) NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)

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