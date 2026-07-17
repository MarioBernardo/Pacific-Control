from sqlalchemy import Integer, String
from sqlalchemy.orm import relationship

from app.extensions import db


class Puesto(db.Model):
    __tablename__ = "puestos"

    id_puesto = db.Column(Integer, primary_key=True)
    nombre_puesto = db.Column(String(100), nullable=False)
    direccion = db.Column(String(200), nullable=False)
    estado = db.Column(String(20), nullable=False)

    dispositivos = relationship("Dispositivo", back_populates="puesto", lazy="select")
    turnos = relationship("Turno", back_populates="puesto", lazy="select")

    def __repr__(self) -> str:
        return f"<Puesto {self.nombre_puesto}>"
