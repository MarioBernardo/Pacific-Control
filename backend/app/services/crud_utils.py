from datetime import date, datetime, time
from decimal import Decimal, InvalidOperation

from sqlalchemy.exc import IntegrityError

from app.extensions import db


class CrudValidationError(Exception):
    def __init__(self, errors: dict[str, str]):
        self.errors = errors
        super().__init__("Datos no válidos.")


class CrudConflictError(Exception):
    pass


def validate_payload(payload: dict, allowed: set[str], required: tuple[str, ...], require_all: bool):
    if not isinstance(payload, dict):
        raise CrudValidationError({"body": "El cuerpo debe ser un objeto JSON."})

    errors = {}
    if set(payload) - allowed:
        errors["body"] = "Contiene campos no permitidos."
    if require_all:
        for field in required:
            if field not in payload:
                errors[field] = "Este campo es obligatorio."
    return errors


def required_string(
    payload: dict, field: str, max_length: int | None, errors: dict
) -> str | None:
    if field not in payload:
        return None
    value = payload[field]
    if not isinstance(value, str) or not value.strip():
        errors[field] = "Debe ser una cadena de texto no vacía."
        return None
    value = value.strip()
    if max_length is not None and len(value) > max_length:
        errors[field] = f"No puede superar {max_length} caracteres."
        return None
    return value


def optional_string(payload: dict, field: str, max_length: int, errors: dict) -> str | None:
    if field not in payload:
        return None
    value = payload[field]
    if value is None:
        return None
    if not isinstance(value, str):
        errors[field] = "Debe ser una cadena de texto o nulo."
        return None
    value = value.strip()
    if len(value) > max_length:
        errors[field] = f"No puede superar {max_length} caracteres."
        return None
    return value


def required_integer(payload: dict, field: str, errors: dict) -> int | None:
    if field not in payload:
        return None
    value = payload[field]
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        errors[field] = "Debe ser un número entero positivo."
        return None
    return value


def required_date(payload: dict, field: str, errors: dict) -> date | None:
    if field not in payload:
        return None
    value = payload[field]
    if not isinstance(value, str):
        errors[field] = "Debe tener formato de fecha ISO 8601."
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        errors[field] = "Debe tener formato de fecha ISO 8601."
        return None


def required_time(payload: dict, field: str, errors: dict) -> time | None:
    if field not in payload:
        return None
    value = payload[field]
    if not isinstance(value, str):
        errors[field] = "Debe tener formato de hora ISO 8601."
        return None
    try:
        return time.fromisoformat(value)
    except ValueError:
        errors[field] = "Debe tener formato de hora ISO 8601."
        return None


def required_datetime(payload: dict, field: str, errors: dict) -> datetime | None:
    if field not in payload:
        return None
    value = payload[field]
    if not isinstance(value, str):
        errors[field] = "Debe tener formato de fecha y hora ISO 8601."
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        errors[field] = "Debe tener formato de fecha y hora ISO 8601."
        return None


def required_decimal(payload: dict, field: str, minimum: Decimal, maximum: Decimal, errors: dict) -> Decimal | None:
    if field not in payload:
        return None
    value = payload[field]
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        errors[field] = "Debe ser un número válido."
        return None
    try:
        value = Decimal(str(value))
    except (InvalidOperation, ValueError):
        errors[field] = "Debe ser un número válido."
        return None
    if not value.is_finite() or not minimum <= value <= maximum:
        errors[field] = f"Debe estar entre {minimum} y {maximum}."
        return None
    return value


def raise_if_invalid(errors: dict, data: dict, require_all: bool) -> None:
    if not require_all and not data and not errors:
        errors["body"] = "Debe enviar al menos un campo para actualizar."
    if errors:
        raise CrudValidationError(errors)


def save_entity(repository, entity, conflict_message: str):
    try:
        return repository.save(entity)
    except IntegrityError as error:
        db.session.rollback()
        raise CrudConflictError(conflict_message) from error
