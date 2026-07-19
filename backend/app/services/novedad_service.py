from app.extensions import db
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.turno import Turno
from app.repositories.novedad_repository import NovedadRepository
from app.services.cache_service import cache_service
from app.services.crud_utils import (
    CrudValidationError,
    raise_if_invalid,
    required_datetime,
    required_integer,
    required_string,
    save_entity,
    validate_payload,
)


class NovedadService:
    _required_fields = ("tipo", "descripcion", "fecha_hora", "estado", "id_empleado", "id_turno")

    def __init__(self, repository: NovedadRepository | None = None):
        self.repository = repository or NovedadRepository()

    def create(self, payload: dict) -> Novedad:
        data = self._validate_data(payload, True)
        self._validate_references(data)
        novedad = save_entity(self.repository, Novedad(**data), "No fue posible guardar la novedad.")
        cache_service.invalidate("novedad", novedad.id_novedad)
        return novedad

    def get_by_id(self, novedad_id: int) -> Novedad | None:
        return cache_service.get_by_id(
            "novedad",
            novedad_id,
            Novedad,
            lambda: self.repository.get_by_id(novedad_id),
        )

    def get_all(self) -> list[Novedad]:
        return cache_service.get_all(
            "novedades", Novedad, lambda: self.repository.get_all()
        )

    def update(self, novedad_id: int, payload: dict) -> Novedad | None:
        novedad = self.repository.get_by_id(novedad_id)
        if novedad is None:
            return None
        data = self._validate_data(payload, False)
        self._validate_references(data)
        for field, value in data.items():
            setattr(novedad, field, value)
        novedad = save_entity(self.repository, novedad, "No fue posible guardar la novedad.")
        cache_service.invalidate("novedad", novedad.id_novedad)
        return novedad

    def change_status(self, novedad_id: int, payload: dict) -> Novedad | None:
        novedad = self.repository.get_by_id(novedad_id)
        if novedad is None:
            return None
        if set(payload) != {"estado"}:
            raise CrudValidationError({"estado": "Debe enviar únicamente el estado."})
        errors = {}
        estado = required_string(payload, "estado", 20, errors)
        raise_if_invalid(errors, {"estado": estado} if estado else {}, True)
        novedad.estado = estado
        novedad = save_entity(self.repository, novedad, "No fue posible guardar la novedad.")
        cache_service.invalidate("novedad", novedad.id_novedad)
        return novedad

    def _validate_data(self, payload: dict, require_all: bool) -> dict:
        errors = validate_payload(payload, set(self._required_fields), self._required_fields, require_all)
        data = {}
        validators = {
            "tipo": lambda: required_string(payload, "tipo", 100, errors),
            "descripcion": lambda: required_string(payload, "descripcion", None, errors),
            "fecha_hora": lambda: required_datetime(payload, "fecha_hora", errors),
            "estado": lambda: required_string(payload, "estado", 20, errors),
            "id_empleado": lambda: required_integer(payload, "id_empleado", errors),
            "id_turno": lambda: required_integer(payload, "id_turno", errors),
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
        if "id_turno" in data and db.session.get(Turno, data["id_turno"]) is None:
            errors["id_turno"] = "El turno indicado no existe."
        if errors:
            raise CrudValidationError(errors)
