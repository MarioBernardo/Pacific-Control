from app.extensions import db
from app.models.dispositivo import Dispositivo
from app.models.puesto import Puesto
from app.repositories.dispositivo_repository import DispositivoRepository
from app.services.crud_utils import (
    CrudConflictError,
    CrudValidationError,
    optional_string,
    raise_if_invalid,
    required_integer,
    required_string,
    save_entity,
    validate_payload,
)


class DispositivoService:
    _required_fields = ("codigo_dispositivo", "estado", "id_puesto")
    _allowed_fields = set(_required_fields) | {"modelo"}

    def __init__(self, repository: DispositivoRepository | None = None):
        self.repository = repository or DispositivoRepository()

    def create(self, payload: dict) -> Dispositivo:
        data = self._validate_data(payload, require_all=True)
        self._ensure_unique(data)
        self._validate_puesto(data)
        return save_entity(
            self.repository, Dispositivo(**data), "No fue posible guardar el dispositivo."
        )

    def get_by_id(self, dispositivo_id: int) -> Dispositivo | None:
        return self.repository.get_by_id(dispositivo_id)

    def get_all(self) -> list[Dispositivo]:
        return self.repository.get_all()

    def update(self, dispositivo_id: int, payload: dict) -> Dispositivo | None:
        dispositivo = self.get_by_id(dispositivo_id)
        if dispositivo is None:
            return None
        data = self._validate_data(payload, require_all=False)
        self._ensure_unique(data, dispositivo.id_dispositivo)
        self._validate_puesto(data)
        for field, value in data.items():
            setattr(dispositivo, field, value)
        return save_entity(self.repository, dispositivo, "No fue posible guardar el dispositivo.")

    def change_status(self, dispositivo_id: int, payload: dict) -> Dispositivo | None:
        dispositivo = self.get_by_id(dispositivo_id)
        if dispositivo is None:
            return None
        if set(payload) != {"estado"}:
            raise CrudValidationError({"estado": "Debe enviar únicamente el estado."})
        errors = {}
        estado = required_string(payload, "estado", 20, errors)
        raise_if_invalid(errors, {"estado": estado} if estado else {}, True)
        dispositivo.estado = estado
        return save_entity(self.repository, dispositivo, "No fue posible guardar el dispositivo.")

    def _validate_data(self, payload: dict, require_all: bool) -> dict:
        errors = validate_payload(payload, self._allowed_fields, self._required_fields, require_all)
        data = {}
        codigo = required_string(payload, "codigo_dispositivo", 50, errors)
        estado = required_string(payload, "estado", 20, errors)
        puesto_id = required_integer(payload, "id_puesto", errors)
        modelo = optional_string(payload, "modelo", 100, errors)
        if "codigo_dispositivo" in payload and codigo is not None:
            data["codigo_dispositivo"] = codigo
        if "estado" in payload and estado is not None:
            data["estado"] = estado
        if "id_puesto" in payload and puesto_id is not None:
            data["id_puesto"] = puesto_id
        if "modelo" in payload:
            data["modelo"] = modelo
        raise_if_invalid(errors, data, require_all)
        return data

    def _ensure_unique(self, data: dict, current_id: int | None = None) -> None:
        codigo = data.get("codigo_dispositivo")
        if codigo:
            dispositivo = self.repository.get_by_codigo(codigo)
            if dispositivo and dispositivo.id_dispositivo != current_id:
                raise CrudConflictError("El código del dispositivo ya está registrado.")

    def _validate_puesto(self, data: dict) -> None:
        puesto_id = data.get("id_puesto")
        if puesto_id and db.session.get(Puesto, puesto_id) is None:
            raise CrudValidationError({"id_puesto": "El puesto indicado no existe."})
