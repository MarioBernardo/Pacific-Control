from decimal import Decimal

from app.extensions import db
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.turno import Turno
from app.repositories.asistencia_repository import AsistenciaRepository
from app.services.cache_service import cache_service
from app.domain import ATTENDANCE_STATES, validate_catalog
from app.services.crud_utils import (
    CrudValidationError,
    optional_operation_id,
    optional_string,
    raise_if_invalid,
    required_datetime,
    required_decimal,
    required_integer,
    required_string,
    save_entity,
    save_idempotent_entity,
    validate_payload,
)


class AsistenciaService:
    _required_fields = ("fecha_hora", "latitud", "longitud", "estado", "id_empleado", "id_turno", "id_dispositivo")
    _allowed_fields = set(_required_fields) | {"foto", "observacion", "operation_id"}

    def __init__(self, repository: AsistenciaRepository | None = None):
        self.repository = repository or AsistenciaRepository()

    def create(self, payload: dict) -> Asistencia:
        data = self._validate_data(payload, True)
        if data.get("operation_id"):
            existing = self.repository.get_by_operation_id(data["operation_id"])
            if existing is not None:
                return existing
        self._validate_references(data)
        asistencia = save_idempotent_entity(self.repository, Asistencia(**data), "No fue posible guardar la asistencia.")
        cache_service.invalidate("asistencia", asistencia.id_asistencia)
        return asistencia

    def get_by_id(self, asistencia_id: int) -> Asistencia | None:
        return self.repository.get_by_id(asistencia_id)

    def get_all(self) -> list[Asistencia]:
        return self.repository.get_all()

    def get_by_operation_id(self, operation_id: str) -> Asistencia | None:
        return self.repository.get_by_operation_id(operation_id)

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
        if not isinstance(payload, dict):
            raise CrudValidationError({"body": "El cuerpo debe ser un objeto JSON."})
        if set(payload) != {"estado"}:
            raise CrudValidationError({"estado": "Debe enviar únicamente el estado."})
        errors = {}
        estado = required_string(payload, "estado", 20, errors)
        validate_catalog(estado, ATTENDANCE_STATES, "estado", errors)
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
            "operation_id": lambda: optional_operation_id(payload, errors),
        }
        for field, validator in validators.items():
            value = validator()
            if field in payload and (value is not None or field in {"foto", "observacion"}):
                data[field] = value
        validate_catalog(data.get("estado"), ATTENDANCE_STATES, "estado", errors)
        raise_if_invalid(errors, data, require_all)
        return data

    def _validate_references(self, data: dict) -> None:
        errors = {}
        empleado = db.session.get(Empleado, data["id_empleado"]) if "id_empleado" in data else None
        turno = db.session.get(Turno, data["id_turno"]) if "id_turno" in data else None
        dispositivo = db.session.get(Dispositivo, data["id_dispositivo"]) if "id_dispositivo" in data else None
        if "id_empleado" in data and (empleado is None or not empleado.estado): errors["id_empleado"] = "El empleado indicado no existe o está inactivo."
        if "id_turno" in data and turno is None: errors["id_turno"] = "El turno indicado no existe."
        if "id_dispositivo" in data and (dispositivo is None or dispositivo.estado != "activo"): errors["id_dispositivo"] = "El dispositivo indicado no existe o está inactivo."
        if empleado and turno and turno.id_empleado != empleado.id_empleado: errors["id_turno"] = "El turno no corresponde al empleado."
        if turno and dispositivo and turno.id_puesto != dispositivo.id_puesto: errors["id_dispositivo"] = "El dispositivo no corresponde al puesto del turno."
        if errors:
            raise CrudValidationError(errors)
