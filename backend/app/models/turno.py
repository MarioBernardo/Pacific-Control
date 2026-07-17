from sqlalchemy import Date, ForeignKey, Integer, String, Time
from sqlalchemy.orm import relationship

from app.extensions import db


class Turno(db.Model):
    __tablename__ = "turnos"

    id_turno = db.Column(Integer, primary_key=True)
    fecha = db.Column(Date, nullable=False)
    hora_inicio = db.Column(Time, nullable=False)
    hora_fin = db.Column(Time, nullable=False)
    estado = db.Column(String(20), nullable=False)
    id_empleado = db.Column(Integer, ForeignKey("empleados.id_empleado"), nullable=False)
    id_puesto = db.Column(Integer, ForeignKey("puestos.id_puesto"), nullable=False)

    empleado = relationship("Empleado", back_populates="turnos", lazy="select")
    puesto = relationship("Puesto", back_populates="turnos", lazy="select")
    asistencias = relationship("Asistencia", back_populates="turno", lazy="select")
    novedades = relationship("Novedad", back_populates="turno", lazy="select")

    def __repr__(self) -> str:
        return f"<Turno {self.id_turno}>"
