import jwt
import os
from fastapi import Header, HTTPException

SECRET_KEY = os.getenv("JWT_SECRET", "gastro_radar_super_secret_123")

def get_current_token_payload(authorization: str = Header(None)):
    """Odczytuje i waliduje token JWT przesyłany z aplikacji mobilnej."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Brak lub nieprawidłowy format tokenu JWT.")
    
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return payload
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Nieprawidłowy lub wygasły token JWT.")