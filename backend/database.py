import asyncpg
from contextlib import asynccontextmanager
from fastapi import FastAPI

DATABASE_URL = "postgresql://postgres:pashalol11@localhost:5432/gastroradar"

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
    pool = await asyncpg.create_pool(DATABASE_URL)
    app.state.db_pool = pool
    # Inicjalizacja struktur bazy danych przy starcie serwera
    await init_db(pool)
    yield
    if pool is not None:
        await pool.close()