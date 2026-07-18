from app.extensions import db
from app.models.dispositivo import Dispositivo


class DispositivoRepository:
    def get_by_id(self, dispositivo_id: int) -> Dispositivo | None:
        return db.session.get(Dispositivo, dispositivo_id)

    def get_all(self) -> list[Dispositivo]:
        return db.session.execute(
            db.select(Dispositivo).order_by(Dispositivo.id_dispositivo)
        ).scalars().all()

    def get_by_codigo(self, codigo: str) -> Dispositivo | None:
        return db.session.execute(
            db.select(Dispositivo).where(Dispositivo.codigo_dispositivo == codigo)
        ).scalar_one_or_none()

    def save(self, dispositivo: Dispositivo) -> Dispositivo:
        db.session.add(dispositivo)
        db.session.commit()
        return dispositivo
