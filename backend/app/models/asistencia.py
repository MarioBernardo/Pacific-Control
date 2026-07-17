from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import relationship

from app.extensions import db


class Asistencia(db.Model):
    __tablename__ = "asistencias"

    id_asistencia = db.Column(Integer, primary_key=True)
    fecha_hora = db.Column(DateTime, nullable=False)
    latitud = db.Column(Numeric(10, 7), nullable=False)
    longitud = db.Column(Numeric(10, 7), nullable=False)
    foto = db.Column(String(255))
    observacion = db.Column(String(255))
    estado = db.Column(String(20), nullable=False)
    id_empleado = db.Column(Integer, ForeignKey("empleados.id_empleado"), nullable=False)
    id_turno = db.Column(Integer, ForeignKey("turnos.id_turno"), nullable=False)
    id_dispositivo = db.Column(Integer, ForeignKey("dispositivos.id_dispositivo"), nullable=False)

    empleado = relationship("Empleado", back_populates="asistencias", lazy="select")
    turno = relationship("Turno", back_populates="asistencias", lazy="select")
    dispositivo = relationship("Dispositivo", back_populates="asistencias", lazy="select")

    def __repr__(self) -> str:
        return f"<Asistencia {self.id_asistencia}>"
