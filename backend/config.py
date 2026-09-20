import os
import secrets
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))


def _positive_integer(value: str | None, default: int) -> int:
    try:
        return max(1, int(value))
    except (TypeError, ValueError):
        return default


def _secret_key(name: str, fallback: str | None = None) -> str:
    """Return an environment-provided secret with a safe HMAC-SHA256 length."""
    value = os.getenv(name) or fallback
    if value is None:
        return secrets.token_urlsafe(48)
    if len(value.encode("utf-8")) < 32:
        raise RuntimeError(f"{name} debe tener al menos 32 bytes.")
    return value


class Config:
    SECRET_KEY = _secret_key("SECRET_KEY")
    FLASK_ENV = os.getenv("FLASK_ENV", "development")
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        "postgresql://postgres:1234@localhost:5432/pacific_control",
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    CACHE_ENABLED = os.getenv("CACHE_ENABLED", "true").lower() == "true"
    REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    CACHE_DEFAULT_TTL = _positive_integer(os.getenv("CACHE_DEFAULT_TTL"), 300)
    OPERATIVE_SESSION_TTL = _positive_integer(os.getenv("OPERATIVE_SESSION_TTL"), 43200)
    DEVICE_LINK_TTL = _positive_integer(os.getenv("DEVICE_LINK_TTL"), 2592000)
    NOVEDAD_UPLOAD_FOLDER = os.getenv(
        "NOVEDAD_UPLOAD_FOLDER", os.path.join(os.path.dirname(__file__), "uploads", "novedades")
    )
    MAX_NOVEDAD_PHOTO_BYTES = _positive_integer(os.getenv("MAX_NOVEDAD_PHOTO_BYTES"), 5 * 1024 * 1024)
    REQUIRE_REDIS_OPERATIVE_SESSION = os.getenv(
        "REQUIRE_REDIS_OPERATIVE_SESSION", "true"
    ).lower() == "true"
    ALLOW_LEGACY_OPERATIVE_DEVICES = os.getenv(
        "ALLOW_LEGACY_OPERATIVE_DEVICES", "false"
    ).lower() == "true"
    DEBUG = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    JWT_SECRET_KEY = _secret_key("JWT_SECRET_KEY", SECRET_KEY)
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=15)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=7)
    JWT_ALGORITHM = "HS256"
    JWT_TOKEN_LOCATION = ["headers"]
    JWT_HEADER_NAME = "Authorization"
    JWT_HEADER_TYPE = "Bearer"
    JWT_QUERY_STRING_NAME = "access_token"
    CELERY_BROKER_URL = REDIS_URL
    CELERY_RESULT_BACKEND = REDIS_URL
