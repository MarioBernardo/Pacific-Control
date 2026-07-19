import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))


def _positive_integer(value: str | None, default: int) -> int:
    try:
        return max(1, int(value))
    except (TypeError, ValueError):
        return default


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "pacific-control-dev-key")
    FLASK_ENV = os.getenv("FLASK_ENV", "development")
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        "postgresql://postgres:1234@localhost:5432/pacific_control",
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    CACHE_ENABLED = os.getenv("CACHE_ENABLED", "true").lower() == "true"
    REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    CACHE_DEFAULT_TTL = _positive_integer(os.getenv("CACHE_DEFAULT_TTL"), 300)
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", SECRET_KEY)
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=15)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=7)
    JWT_ALGORITHM = "HS256"
    JWT_TOKEN_LOCATION = ["headers"]
    JWT_HEADER_NAME = "Authorization"
    JWT_HEADER_TYPE = "Bearer"
    JWT_QUERY_STRING_NAME = "access_token"
    CELERY_BROKER_URL = REDIS_URL
    CELERY_RESULT_BACKEND = REDIS_URL
