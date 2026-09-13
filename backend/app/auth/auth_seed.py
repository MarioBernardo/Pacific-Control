from typing import Optional

from werkzeug.security import generate_password_hash

from app.extensions import db
from app.models.empleado import Empleado
from app.repositories.empleado_repository import EmpleadoRepository


DEMO_USERS = (
    {
        "cedula": "0900000001",
        "nombres": "Admin",
        "apellidos": "Demo",
        "correo": "admin@pacific.test",
        "telefono": "0990000001",
        "cargo": "ADMINISTRADOR",
        "password": "Admin123!",
        "estado": True,
    },
    {
        "cedula": "0900000002",
        "nombres": "Supervisor",
        "apellidos": "Demo",
        "correo": "supervisor@pacific.test",
        "telefono": "0990000002",
        "cargo": "SUPERVISOR",
        "password": "Supervisor123!",
        "estado": True,
    },
    {
        "cedula": "0900000003",
        "nombres": "Guardia",
        "apellidos": "Demo",
        "correo": "guardia@pacific.test",
        "telefono": "0990000003",
        "cargo": "GUARDIA",
        "password": "Guardia123!",
        "estado": True,
    },
    {
        "cedula": "0900000099",
        "nombres": "Guardia",
        "apellidos": "Demo",
        "correo": "guardia.demo@pacific.test",
        "telefono": "0990000099",
        "cargo": "GUARDIA",
        "password": "Guardia123!",
        "estado": True,
    },
    {
        "cedula": "0900000004",
        "nombres": "Inactivo",
        "apellidos": "Demo",
        "correo": "inactivo@pacific.test",
        "telefono": "0990000004",
        "cargo": "GUARDIA",
        "password": "Inactivo123!",
        "estado": False,
    },
)


def seed_demo_users() -> list[Empleado]:
    """Create or reconcile the documented demo accounts without duplicates."""
    users = []
    repository = EmpleadoRepository()
    for data in DEMO_USERS:
        empleado = repository.get_by_correo(data["correo"])
        if empleado is None:
            empleado = Empleado(
                cedula=data["cedula"],
                nombres=data["nombres"],
                apellidos=data["apellidos"],
                correo=data["correo"],
                telefono=data["telefono"],
                cargo=data["cargo"],
                estado=data["estado"],
            )
            db.session.add(empleado)
        else:
            empleado.cargo = data["cargo"]
            empleado.estado = data["estado"]

        empleado.password_hash = generate_password_hash(data["password"])
        users.append(empleado)

    db.session.commit()
    return users


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
