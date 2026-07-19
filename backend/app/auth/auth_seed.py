from typing import Optional

from werkzeug.security import generate_password_hash

from app.models.empleado import Empleado
from app.repositories.empleado_repository import EmpleadoRepository


def initialize_password(correo: str, password: str = "123456") -> str:
    """Initialize an empleado password when no password_hash is present.

    The function looks up the empleado by correo using EmpleadoRepository.
    If the empleado does not exist, it returns an informative message.
    If the empleado already has a password_hash, it returns a message and does not
    modify the record.
    Otherwise, it hashes the provided password and saves the empleado.

    Args:
        correo: The empleado email address used to find the record.
        password: The plaintext password to hash and store.

    Returns:
        A status message describing the result.
    """
    repository = EmpleadoRepository()
    empleado: Optional[Empleado] = repository.get_by_correo(correo)

    if empleado is None:
        return "Empleado no encontrado."

    if empleado.password_hash is not None:
        return "El empleado ya tiene contraseña configurada."

    empleado.password_hash = generate_password_hash(password)
    repository.save(empleado)
    return "Contraseña inicializada correctamente."
