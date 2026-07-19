from typing import Optional

from werkzeug.security import generate_password_hash

from app.repositories.empleado_repository import EmpleadoRepository
from app.models.empleado import Empleado


def initialize_test_password(correo: str, password: str = "123456") -> str:
    """Initialize a test password for an empleado if password_hash is missing."""
    repository = EmpleadoRepository()
    empleado: Optional[Empleado] = repository.get_by_correo(correo)

    if empleado is None:
        return f"Empleado con correo '{correo}' no encontrado."

    if empleado.password_hash is not None:
        return f"Empleado '{correo}' ya tenía contraseña." 

    empleado.password_hash = generate_password_hash(password)
    repository.save(empleado)
    return f"Empleado '{correo}' actualizado."