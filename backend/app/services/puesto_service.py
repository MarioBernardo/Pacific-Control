from app.models.puesto import Puesto
from app.repositories.puesto_repository import PuestoRepository
from app.services.crud_utils import (
    CrudValidationError,
    required_string,
    raise_if_invalid,
    save_entity,
    validate_payload,
)


class PuestoService:
    _required_fields = ("nombre_puesto", "direccion", "estado")
    _field_lengths = {"nombre_puesto": 100, "direccion": 200, "estado": 20}

    def __init__(self, repository: PuestoRepository | None = None):
        self.repository = repository or PuestoRepository()

    def create(self, payload: dict) -> Puesto:
        puesto = Puesto(**self._validate_data(payload, require_all=True))
        return save_entity(self.repository, puesto, "No fue posible guardar el puesto.")

    def get_by_id(self, puesto_id: int) -> Puesto | None:
        return self.repository.get_by_id(puesto_id)

    def get_all(self) -> list[Puesto]:
        return self.repository.get_all()

    def update(self, puesto_id: int, payload: dict) -> Puesto | None:
        puesto = self.get_by_id(puesto_id)
        if puesto is None:
            return None
        for field, value in self._validate_data(payload, require_all=False).items():
            setattr(puesto, field, value)
        return save_entity(self.repository, puesto, "No fue posible guardar el puesto.")

    def change_status(self, puesto_id: int, payload: dict) -> Puesto | None:
        puesto = self.get_by_id(puesto_id)
        if puesto is None:
            return None
        if set(payload) != {"estado"}:
            raise CrudValidationError({"estado": "Debe enviar únicamente el estado."})
        puesto.estado = self._validate_status(payload)
        return save_entity(self.repository, puesto, "No fue posible guardar el puesto.")

    def _validate_data(self, payload: dict, require_all: bool) -> dict:
        errors = validate_payload(payload, set(self._required_fields), self._required_fields, require_all)
        data = {}
        for field in self._required_fields:
            value = required_string(payload, field, self._field_lengths[field], errors)
            if field in payload and value is not None:
                data[field] = value
        raise_if_invalid(errors, data, require_all)
        return data

    def _validate_status(self, payload: dict) -> str:
        errors = {}
        value = required_string(payload, "estado", self._field_lengths["estado"], errors)
        raise_if_invalid(errors, {"estado": value} if value else {}, True)
        return value
