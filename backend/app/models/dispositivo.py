from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.extensions import db


class Dispositivo(db.Model):
    __tablename__ = "dispositivos"

    id_dispositivo = db.Column(Integer, primary_key=True)
    codigo_dispositivo = db.Column(String(50), unique=True, nullable=False)
    modelo = db.Column(String(100))
    estado = db.Column(String(20), nullable=False)
    id_puesto = db.Column(Integer, ForeignKey("puestos.id_puesto"), nullable=False)

    puesto = relationship("Puesto", back_populates="dispositivos", lazy="select")
    asistencias = relationship("Asistencia", back_populates="dispositivo", lazy="select")

    def __repr__(self) -> str:
        return f"<Dispositivo {self.codigo_dispositivo}>"
