from typing import Any, Dict

from werkzeug.security import check_password_hash
from flask_jwt_extended import create_access_token

from app.repositories.empleado_repository import EmpleadoRepository
from app.models.empleado import Empleado


class AuthenticationError(Exception):
    """Authentication failed."""


class AuthService:
    """Service responsible for authenticating empleados."""

    def __init__(self, repository: EmpleadoRepository | None = None):
        self.repository = repository or EmpleadoRepository()

    def login(self, correo: str, password: str) -> Dict[str, Any]:
        """Authenticate an empleado and return access token payload."""
        empleado = self.repository.get_by_correo(correo)
        if empleado is None:
            raise AuthenticationError("Credenciales inválidas.")

        if empleado.password_hash is None:
            raise AuthenticationError("Credenciales inválidas.")

        if not check_password_hash(empleado.password_hash, password):
            raise AuthenticationError("Credenciales inválidas.")

        claims = {
            "cargo": empleado.cargo,
            "correo": empleado.correo,
        }
        access_token = create_access_token(identity=str(empleado.id_empleado), additional_claims=claims)

        return {
            "access_token": access_token,
            "empleado": {
                "id": empleado.id_empleado,
                "nombres": empleado.nombres,
                "apellidos": empleado.apellidos,
                "correo": empleado.correo,
                "cargo": empleado.cargo,
            },
        }
