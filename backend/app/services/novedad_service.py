import logging
from app.extensions import db
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.turno import Turno
from app.repositories.novedad_repository import NovedadRepository
from app.services.cache_service import cache_service
from app.domain import INCIDENT_STATES, validate_catalog
from app.services.crud_utils import (
    CrudValidationError,
    optional_operation_id,
    raise_if_invalid,
    required_datetime,
    required_integer,
    required_string,
    save_entity,
    save_idempotent_entity,
    validate_payload,
)


class NovedadService:
    _required_fields = (
        "tipo",
        "descripcion",
        "fecha_hora",
        "estado",
        "id_empleado",
        "id_turno",
    )
    _allowed_fields = set(_required_fields) | {"evidencia_foto", "id_dispositivo", "operation_id"}

    def __init__(self, repository: NovedadRepository | None = None):
        self.repository = repository or NovedadRepository()

    def create(self, payload: dict) -> Novedad:
        data = self._validate_data(payload, True)
        if data.get("operation_id"):
            existing = self.repository.get_by_operation_id(data["operation_id"])
            if existing is not None:
                return existing
        self._validate_references(data)

        novedad = save_idempotent_entity(
            self.repository,
            Novedad(**data),
            "No fue posible guardar la novedad.",
        )

        # Invalidar caché
        cache_service.invalidate("novedad", novedad.id_novedad)

        # Import local para evitar importación circular
        from app.tasks import process_novedad

        # Procesamiento asíncrono
        try:
            process_novedad.delay(novedad.id_novedad)
        except Exception as error:
            logging.getLogger(__name__).warning("Novedad %s persistida; broker no disponible: %s", novedad.id_novedad, error)

        return novedad

    def get_by_id(self, novedad_id: int) -> Novedad | None:
        return self.repository.get_by_id(novedad_id)

    def get_all(self) -> list[Novedad]:
        return self.repository.get_all()

    def get_by_operation_id(self, operation_id: str) -> Novedad | None:
        return self.repository.get_by_operation_id(operation_id)

    def update(self, novedad_id: int, payload: dict) -> Novedad | None:
        novedad = self.repository.get_by_id(novedad_id)

        if novedad is None:
            return None

        data = self._validate_data(payload, False)
        self._validate_references(data)

        for field, value in data.items():
            setattr(novedad, field, value)

        novedad = save_entity(
            self.repository,
            novedad,
            "No fue posible guardar la novedad.",
        )

        cache_service.invalidate("novedad", novedad.id_novedad)

        return novedad

    def change_status(self, novedad_id: int, payload: dict) -> Novedad | None:
        novedad = self.repository.get_by_id(novedad_id)

        if novedad is None:
            return None

        if not isinstance(payload, dict):
            raise CrudValidationError({"body": "El cuerpo debe ser un objeto JSON."})
        if set(payload) != {"estado"}:
            raise CrudValidationError(
                {"estado": "Debe enviar únicamente el estado."}
            )

        errors = {}

        estado = required_string(payload, "estado", 20, errors)
        validate_catalog(estado, INCIDENT_STATES, "estado", errors)

        raise_if_invalid(
            errors,
            {"estado": estado} if estado else {},
            True,
        )

        novedad.estado = estado

        novedad = save_entity(
            self.repository,
            novedad,
            "No fue posible guardar la novedad.",
        )

        cache_service.invalidate("novedad", novedad.id_novedad)

        return novedad

    def _validate_data(self, payload: dict, require_all: bool) -> dict:
        errors = validate_payload(
            payload,
            self._allowed_fields,
            self._required_fields,
            require_all,
        )

        data = {}

        validators = {
            "tipo": lambda: required_string(payload, "tipo", 100, errors),
            "descripcion": lambda: required_string(payload, "descripcion", None, errors),
            "fecha_hora": lambda: required_datetime(payload, "fecha_hora", errors),
            "estado": lambda: required_string(payload, "estado", 20, errors),
            "id_empleado": lambda: required_integer(payload, "id_empleado", errors),
            "id_turno": lambda: required_integer(payload, "id_turno", errors),
            "id_dispositivo": lambda: required_integer(payload, "id_dispositivo", errors),
            "operation_id": lambda: optional_operation_id(payload, errors),
        }

        for field, validator in validators.items():
            value = validator()

            if field in payload and value is not None:
                data[field] = value

        if "evidencia_foto" in payload:
            value = payload.get("evidencia_foto")
            if value is not None and (not isinstance(value, str) or len(value) > 255):
                errors["evidencia_foto"] = "La referencia de evidencia no es válida."
            else:
                data["evidencia_foto"] = value

        validate_catalog(data.get("estado"), INCIDENT_STATES, "estado", errors)
        raise_if_invalid(errors, data, require_all)

        return data

    def _validate_references(self, data: dict) -> None:
        errors = {}
        empleado = db.session.get(Empleado, data["id_empleado"]) if "id_empleado" in data else None
        turno = db.session.get(Turno, data["id_turno"]) if "id_turno" in data else None
        if "id_empleado" in data and (empleado is None or not empleado.estado):
            errors["id_empleado"] = "El empleado indicado no existe o está inactivo."
        if "id_turno" in data and turno is None:
            errors["id_turno"] = "El turno indicado no existe."
        if empleado and turno and turno.id_empleado != empleado.id_empleado:
            errors["id_turno"] = "El turno no corresponde al empleado."
        if errors:
            raise CrudValidationError(errors)
