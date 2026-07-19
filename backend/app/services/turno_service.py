from app.extensions import db
from app.models.empleado import Empleado
from app.models.puesto import Puesto
from app.models.turno import Turno
from app.repositories.turno_repository import TurnoRepository
from app.services.cache_service import cache_service
from app.services.crud_utils import (
    CrudValidationError,
    raise_if_invalid,
    required_date,
    required_integer,
    required_string,
    required_time,
    save_entity,
    validate_payload,
)


class TurnoService:
    _required_fields = ("fecha", "hora_inicio", "hora_fin", "estado", "id_empleado", "id_puesto")

    def __init__(self, repository: TurnoRepository | None = None):
        self.repository = repository or TurnoRepository()

    def create(self, payload: dict) -> Turno:
        data = self._validate_data(payload, True)
        turno = save_entity(self.repository, Turno(**data), "No fue posible guardar el turno.")
        cache_service.invalidate("turno", turno.id_turno)
        return turno

    def get_by_id(self, turno_id: int) -> Turno | None:
        return cache_service.get_by_id(
            "turno",
            turno_id,
            Turno,
            lambda: self.repository.get_by_id(turno_id),
        )

    def get_all(self) -> list[Turno]:
        return cache_service.get_all(
            "turnos", Turno, lambda: self.repository.get_all()
        )

    def update(self, turno_id: int, payload: dict) -> Turno | None:
        turno = self.repository.get_by_id(turno_id)
        if turno is None:
            return None
        data = self._validate_data(payload, False)
        self._validate_references(data)
        for field, value in data.items():
            setattr(turno, field, value)
        turno = save_entity(self.repository, turno, "No fue posible guardar el turno.")
        cache_service.invalidate("turno", turno.id_turno)
        return turno

    def change_status(self, turno_id: int, payload: dict) -> Turno | None:
        turno = self.repository.get_by_id(turno_id)
        if turno is None:
            return None
        if set(payload) != {"estado"}:
            raise CrudValidationError({"estado": "Debe enviar únicamente el estado."})
        errors = {}
        estado = required_string(payload, "estado", 20, errors)
        raise_if_invalid(errors, {"estado": estado} if estado else {}, True)
        turno.estado = estado
        turno = save_entity(self.repository, turno, "No fue posible guardar el turno.")
        cache_service.invalidate("turno", turno.id_turno)
        return turno

    def _validate_data(self, payload: dict, require_all: bool) -> dict:
        errors = validate_payload(payload, set(self._required_fields), self._required_fields, require_all)
        data = {}
        validators = {
            "fecha": lambda: required_date(payload, "fecha", errors),
            "hora_inicio": lambda: required_time(payload, "hora_inicio", errors),
            "hora_fin": lambda: required_time(payload, "hora_fin", errors),
            "estado": lambda: required_string(payload, "estado", 20, errors),
            "id_empleado": lambda: required_integer(payload, "id_empleado", errors),
            "id_puesto": lambda: required_integer(payload, "id_puesto", errors),
        }
        for field, validator in validators.items():
            value = validator()
            if field in payload and value is not None:
                data[field] = value
        raise_if_invalid(errors, data, require_all)
        return data

    def _validate_references(self, data: dict) -> None:
        errors = {}
        if "id_empleado" in data and db.session.get(Empleado, data["id_empleado"]) is None:
            errors["id_empleado"] = "El empleado indicado no existe."
        if "id_puesto" in data and db.session.get(Puesto, data["id_puesto"]) is None:
            errors["id_puesto"] = "El puesto indicado no existe."
        if errors:
            raise CrudValidationError(errors)
