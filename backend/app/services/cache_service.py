from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import Date, DateTime, Numeric, Time, inspect

from app.extensions import cache


class CacheService:
    def get_by_id(self, resource: str, item_id: int, model_class, loader):
        key = self._item_key(resource, item_id)
        payload = cache.get_json(key)
        if payload is not None:
            return self._to_model(model_class, payload)

        item = loader()
        if item is not None:
            cache.set_json(key, self._to_payload(item))
        return item

    def get_all(self, resource: str, model_class, loader):
        key = self._list_key(resource)
        payload = cache.get_json(key)
        if payload is not None:
            return [self._to_model(model_class, item) for item in payload]

        items = loader()
        cache.set_json(key, [self._to_payload(item) for item in items])
        return items

    def invalidate(self, resource: str, item_id: int) -> None:
        cache.delete(self._item_key(resource, item_id), self._list_key(resource))

    @staticmethod
    def _item_key(resource: str, item_id: int) -> str:
        return f"pacific-control:{resource}:{item_id}"

    @staticmethod
    def _list_key(resource: str) -> str:
        return f"pacific-control:{resource}:all"

    @staticmethod
    def _to_payload(model) -> dict:
        payload = {}
        for column in inspect(model.__class__).columns:
            value = getattr(model, column.name)
            if isinstance(value, (date, datetime, time)):
                value = value.isoformat()
            elif isinstance(value, Decimal):
                value = str(value)
            payload[column.name] = value
        return payload

    @staticmethod
    def _to_model(model_class, payload: dict):
        values = {}
        for column in inspect(model_class).columns:
            value = payload.get(column.name)
            if value is not None:
                if isinstance(column.type, DateTime):
                    value = datetime.fromisoformat(value)
                elif isinstance(column.type, Date):
                    value = date.fromisoformat(value)
                elif isinstance(column.type, Time):
                    value = time.fromisoformat(value)
                elif isinstance(column.type, Numeric):
                    value = Decimal(value)
            values[column.name] = value
        return model_class(**values)


cache_service = CacheService()
