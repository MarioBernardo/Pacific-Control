import json
import logging


logger = logging.getLogger(__name__)


class RedisCache:
    def __init__(self):
        self._client = None
        self._enabled = False
        self._ttl = 300
        self._redis_errors = (OSError,)

    def init_app(self, app) -> None:
        self._ttl = app.config["CACHE_DEFAULT_TTL"]
        if not app.config["CACHE_ENABLED"]:
            return

        try:
            import redis
        except ImportError:
            logger.warning("Redis no está instalado; la caché permanecerá deshabilitada.")
            return

        self._client = redis.from_url(
            app.config["REDIS_URL"],
            decode_responses=True,
            socket_connect_timeout=0.2,
            socket_timeout=0.2,
        )
        self._redis_errors = (redis.RedisError, OSError)
        self._enabled = True

    def get_json(self, key: str):
        value = self._execute("get", key)
        if value is None:
            return None
        try:
            return json.loads(value)
        except (TypeError, ValueError):
            self.delete(key)
            return None

    def set_json(self, key: str, value) -> None:
        self._execute("set", key, json.dumps(value), ex=self._ttl)

    def delete(self, *keys: str) -> None:
        if keys:
            self._execute("delete", *keys)

    def _execute(self, operation: str, *args, **kwargs):
        if not self._enabled or self._client is None:
            return None
        try:
            return getattr(self._client, operation)(*args, **kwargs)
        except self._redis_errors as error:
            logger.warning("Redis no está disponible; se utilizará la base de datos: %s", error)
            self._enabled = False
            return None
