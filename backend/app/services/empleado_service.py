from sqlalchemy.exc import IntegrityError

from app.extensions import db
from app.models.empleado import Empleado
from app.repositories.empleado_repository import EmpleadoRepository


class EmpleadoValidationError(Exception):
    def __init__(self, errors: dict[str, str]):
        self.errors = errors
        super().__init__("Datos de empleado no válidos")


class EmpleadoConflictError(Exception):
    pass


class EmpleadoService:
    _required_fields = (
        "cedula",
        "nombres",
        "apellidos",
        "correo",
        "telefono",
        "cargo",
    )
    _field_lengths = {
        "cedula": 10,
        "nombres": 100,
        "apellidos": 100,
        "correo": 120,
        "telefono": 15,
        "cargo": 50,
    }

    def __init__(self, repository: EmpleadoRepository | None = None):
        self.repository = repository or EmpleadoRepository()

    def create(self, payload: dict) -> Empleado:
        data = self._validate_employee_data(payload, require_all=True)
        self._ensure_unique(data)

        empleado = Empleado(**data)
        return self._save(empleado)

    def get_by_id(self, empleado_id: int) -> Empleado | None:
        return self.repository.get_by_id(empleado_id)

    def get_all(self) -> list[Empleado]:
        return self.repository.get_all()

    def update(self, empleado_id: int, payload: dict) -> Empleado | None:
        empleado = self.get_by_id(empleado_id)
        if empleado is None:
            return None

        data = self._validate_employee_data(payload, require_all=False)
        self._ensure_unique(data, empleado.id_empleado)

        for field, value in data.items():
            setattr(empleado, field, value)

        return self._save(empleado)

    def change_status(self, empleado_id: int, payload: dict) -> Empleado | None:
        empleado = self.get_by_id(empleado_id)
        if empleado is None:
            return None

        if set(payload) != {"estado"} or not isinstance(payload["estado"], bool):
            raise EmpleadoValidationError(
                {"estado": "Debe enviarse únicamente un valor booleano para estado."}
            )

        empleado.estado = payload["estado"]
        return self._save(empleado)

    def _validate_employee_data(self, payload: dict, require_all: bool) -> dict:
        if not isinstance(payload, dict):
            raise EmpleadoValidationError({"body": "El cuerpo debe ser un objeto JSON."})

        allowed_fields = set(self._required_fields) | {"estado"}
        errors = {}
        unknown_fields = set(payload) - allowed_fields
        if unknown_fields:
            errors["body"] = "Contiene campos no permitidos."

        if require_all:
            for field in self._required_fields:
                if field not in payload:
                    errors[field] = "Este campo es obligatorio."

        data = {}
        for field in self._required_fields:
            if field not in payload:
                continue
            value = payload[field]
            if not isinstance(value, str) or not value.strip():
                errors[field] = "Debe ser una cadena de texto no vacía."
                continue

            value = value.strip()
            if len(value) > self._field_lengths[field]:
                errors[field] = (
                    f"No puede superar {self._field_lengths[field]} caracteres."
                )
                continue
            data[field] = value

        correo = data.get("correo")
        if correo and ("@" not in correo or correo.startswith("@") or correo.endswith("@")):
            errors["correo"] = "Debe tener un formato de correo válido."

        if "estado" in payload:
            if not isinstance(payload["estado"], bool):
                errors["estado"] = "Debe ser un valor booleano."
            else:
                data["estado"] = payload["estado"]

        if not require_all and not data and not errors:
            errors["body"] = "Debe enviar al menos un campo para actualizar."

        if errors:
            raise EmpleadoValidationError(errors)
        return data

    def _ensure_unique(self, data: dict, current_id: int | None = None) -> None:
        cedula = data.get("cedula")
        if cedula:
            empleado = self.repository.get_by_cedula(cedula)
            if empleado and empleado.id_empleado != current_id:
                raise EmpleadoConflictError("La cédula ya está registrada.")

        correo = data.get("correo")
        if correo:
            empleado = self.repository.get_by_correo(correo)
            if empleado and empleado.id_empleado != current_id:
                raise EmpleadoConflictError("El correo ya está registrado.")

    def _save(self, empleado: Empleado) -> Empleado:
        try:
            return self.repository.save(empleado)
        except IntegrityError as error:
            db.session.rollback()
            raise EmpleadoConflictError(
                "La cédula o el correo ya está registrado."
            ) from error
