import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import lifespan
from routers import users, restaurants, auth

app = FastAPI(title="GastroRadar API", lifespan=lifespan)

# Konfiguracja CORS (pozwala na dostęp np. z przeglądarki Web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(restaurants.router)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)