from decimal import Decimal

from app.extensions import db
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.turno import Turno
from app.repositories.asistencia_repository import AsistenciaRepository
from app.services.crud_utils import (
    CrudValidationError,
    optional_string,
    raise_if_invalid,
    required_datetime,
    required_decimal,
    required_integer,
    required_string,
    save_entity,
    validate_payload,
)


class AsistenciaService:
    _required_fields = ("fecha_hora", "latitud", "longitud", "estado", "id_empleado", "id_turno", "id_dispositivo")
    _allowed_fields = set(_required_fields) | {"foto", "observacion"}

    def __init__(self, repository: AsistenciaRepository | None = None):
        self.repository = repository or AsistenciaRepository()

    def create(self, payload: dict) -> Asistencia:
        data = self._validate_data(payload, True)
        self._validate_references(data)
        asistencia = save_entity(self.repository, Asistencia(**data), "No fue posible guardar la asistencia.")
        cache_service.invalidate("asistencia", asistencia.id_asistencia)
        return asistencia

    def get_by_id(self, asistencia_id: int) -> Asistencia | None:
        return cache_service.get_by_id(
            "asistencia",
            asistencia_id,
            Asistencia,
            lambda: self.repository.get_by_id(asistencia_id),
        )

    def get_all(self) -> list[Asistencia]:
        return cache_service.get_all(
            "asistencias", Asistencia, lambda: self.repository.get_all()
        )

    def update(self, asistencia_id: int, payload: dict) -> Asistencia | None:
        asistencia = self.repository.get_by_id(asistencia_id)
        if asistencia is None:
            return None
        data = self._validate_data(payload, False)
        self._validate_references(data)
        for field, value in data.items():
            setattr(asistencia, field, value)
        asistencia = save_entity(self.repository, asistencia, "No fue posible guardar la asistencia.")
        cache_service.invalidate("asistencia", asistencia.id_asistencia)
        return asistencia

    def change_status(self, asistencia_id: int, payload: dict) -> Asistencia | None:
        asistencia = self.repository.get_by_id(asistencia_id)
        if asistencia is None:
            return None
        if set(payload) != {"estado"}:
            raise CrudValidationError({"estado": "Debe enviar únicamente el estado."})
        errors = {}
        estado = required_string(payload, "estado", 20, errors)
        raise_if_invalid(errors, {"estado": estado} if estado else {}, True)
        asistencia.estado = estado
        asistencia = save_entity(self.repository, asistencia, "No fue posible guardar la asistencia.")
        cache_service.invalidate("asistencia", asistencia.id_asistencia)
        return asistencia

    def _validate_data(self, payload: dict, require_all: bool) -> dict:
        errors = validate_payload(payload, self._allowed_fields, self._required_fields, require_all)
        data = {}
        validators = {
            "fecha_hora": lambda: required_datetime(payload, "fecha_hora", errors),
            "latitud": lambda: required_decimal(payload, "latitud", Decimal("-90"), Decimal("90"), errors),
            "longitud": lambda: required_decimal(payload, "longitud", Decimal("-180"), Decimal("180"), errors),
            "estado": lambda: required_string(payload, "estado", 20, errors),
            "id_empleado": lambda: required_integer(payload, "id_empleado", errors),
            "id_turno": lambda: required_integer(payload, "id_turno", errors),
            "id_dispositivo": lambda: required_integer(payload, "id_dispositivo", errors),
            "foto": lambda: optional_string(payload, "foto", 255, errors),
            "observacion": lambda: optional_string(payload, "observacion", 255, errors),
        }
        for field, validator in validators.items():
            value = validator()
            if field in payload and (value is not None or field in {"foto", "observacion"}):
                data[field] = value
        raise_if_invalid(errors, data, require_all)
        return data

    def _validate_references(self, data: dict) -> None:
        checks = (("id_empleado", Empleado, "empleado"), ("id_turno", Turno, "turno"), ("id_dispositivo", Dispositivo, "dispositivo"))
        errors = {}
        for field, model, label in checks:
            if field in data and db.session.get(model, data[field]) is None:
                errors[field] = f"El {label} indicado no existe."
        if errors:
            raise CrudValidationError(errors)
