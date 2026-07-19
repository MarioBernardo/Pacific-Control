from sqlalchemy import Boolean, Integer, String
from sqlalchemy.orm import relationship

from app.extensions import db


class Empleado(db.Model):
    __tablename__ = "empleados"

    id_empleado = db.Column(Integer, primary_key=True)
    cedula = db.Column(String(10), unique=True, nullable=False)
    nombres = db.Column(String(100), nullable=False)
    apellidos = db.Column(String(100), nullable=False)
    correo = db.Column(String(120), unique=True, nullable=False)
    password_hash = db.Column(String(255), nullable=True)
    telefono = db.Column(String(15), nullable=False)
    cargo = db.Column(String(50), nullable=False)
    estado = db.Column(Boolean, default=True, nullable=False)

    # Relaciones
    turnos = relationship(
        "Turno",
        back_populates="empleado",
        lazy="select"
    )

    asistencias = relationship(
        "Asistencia",
        back_populates="empleado",
        lazy="select"
    )

    novedades = relationship(
        "Novedad",
        back_populates="empleado",
        lazy="select"
    )

    def __repr__(self):
        return (
            f"<Empleado(id={self.id_empleado}, "
            f"nombre='{self.nombres} {self.apellidos}')>"
        )