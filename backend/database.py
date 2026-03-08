import os
import asyncpg
from contextlib import asynccontextmanager
from fastapi import FastAPI
from dotenv import load_dotenv

# Ładowanie zmiennych środowiskowych z pliku .env
load_dotenv()

# Bezpieczne pobieranie adresu bazy danych
DATABASE_URL = os.getenv("DATABASE_URL")

async def init_db(pool):
    """Tworzy tabelę na oczekujące powiadomienia, jeśli jeszcze nie istnieje."""
    async with pool.acquire() as conn:
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
    # Zabezpieczenie przed brakiem pliku .env
    if not DATABASE_URL:
        raise ValueError("CRITICAL: Brak zmiennej DATABASE_URL. Sprawdź plik .env!")
        
    pool = await asyncpg.create_pool(DATABASE_URL)
    app.state.db_pool = pool
    
    # Inicjalizacja struktur bazy danych przy starcie serwera
    await init_db(pool)
    
    yield
    
    if pool is not None:
        await pool.close()