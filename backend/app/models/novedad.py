from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.extensions import db


class Novedad(db.Model):
    __tablename__ = "novedades"

    id_novedad = db.Column(Integer, primary_key=True)
    tipo = db.Column(String(100), nullable=False)
    descripcion = db.Column(Text, nullable=False)
    fecha_hora = db.Column(DateTime, nullable=False)
    estado = db.Column(String(20), nullable=False)
    id_empleado = db.Column(Integer, ForeignKey("empleados.id_empleado"), nullable=False)
    id_turno = db.Column(Integer, ForeignKey("turnos.id_turno"), nullable=False)

    empleado = relationship("Empleado", back_populates="novedades", lazy="select")
    turno = relationship("Turno", back_populates="novedades", lazy="select")

    def __repr__(self) -> str:
        return f"<Novedad {self.id_novedad}>"
