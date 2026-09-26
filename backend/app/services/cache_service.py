from collections.abc import Callable
from typing import Any

from app.extensions import cache


class CacheService:
    """Cache serialized response DTOs, never partially hydrated ORM models."""

    COLLECTIONS = {"empleado": "empleados", "puesto": "puestos", "dispositivo": "dispositivos", "turno": "turnos", "asistencia": "asistencias", "novedad": "novedades"}
    RELATED_DTOS = {
        "empleado": ("turno", "asistencia", "novedad"),
        "puesto": ("dispositivo", "turno", "asistencia", "novedad"),
        "dispositivo": ("asistencia", "novedad"),
        "turno": ("asistencia", "novedad"),
    }
    def get_by_id(
        self,
        resource: str,
        item_id: int,
        loader: Callable[[], Any | None],
        serializer: Callable[[Any], dict],
    ) -> dict | None:
        key = self._item_key(resource, item_id)
        payload = cache.get_json(key)
        if isinstance(payload, dict):
            return payload

        item = loader()
        if item is None:
            return None
        payload = serializer(item)
        cache.set_json(key, payload)
        return payload

    def get_all(
        self,
        resource: str,
        loader: Callable[[], list[Any]],
        serializer: Callable[[Any], dict],
    ) -> list[dict]:
        key = self._list_key(resource)
        payload = cache.get_json(key)
        if isinstance(payload, list):
            return payload

        items = loader()
        payload = [serializer(item) for item in items]
        cache.set_json(key, payload)
        return payload

    def invalidate(self, resource: str, item_id: int) -> None:
        singular = next((key for key, value in self.COLLECTIONS.items() if value == resource), resource)
        resources = {singular, self.COLLECTIONS.get(singular, resource)}
        keys = []
        for current_resource in resources:
            keys.extend(
                (
                    self._item_key(current_resource, item_id),
                    self._list_key(current_resource),
                )
            )
        cache.delete(*keys)
        for dependent in self.RELATED_DTOS.get(singular, ()):
            cache.delete(self._list_key(self.COLLECTIONS[dependent]))
            cache.delete_pattern(f"pacific-control:{dependent}:*")

    @staticmethod
    def _item_key(resource: str, item_id: int) -> str:
        return f"pacific-control:{resource}:{item_id}"

    @staticmethod
    def _list_key(resource: str) -> str:
        return f"pacific-control:{resource}:all"

cache_service = CacheService()
