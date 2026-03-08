import uvicorn
from fastapi import FastAPI
from database import lifespan
from routers import users, restaurants

app = FastAPI(
    title="GastroRadar API",
    description="Backend cienkiego klienta z obsługą PostGIS i systemem powiadomień",
    version="1.0.0",
    lifespan=lifespan
)

# Rejestracja routerów
app.include_router(users.router)
app.include_router(restaurants.router)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)