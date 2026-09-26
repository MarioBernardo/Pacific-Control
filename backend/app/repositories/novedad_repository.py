from app.extensions import db
from app.models.novedad import Novedad


class NovedadRepository:
    def get_by_id(self, novedad_id: int) -> Novedad | None:
        return db.session.get(Novedad, novedad_id)

    def get_all(self) -> list[Novedad]:
        return db.session.execute(
            db.select(Novedad).order_by(Novedad.id_novedad)
        ).scalars().all()

    def get_by_operation_id(self, operation_id: str) -> Novedad | None:
        return db.session.execute(
            db.select(Novedad).where(Novedad.operation_id == operation_id)
        ).scalar_one_or_none()

    def save(self, novedad: Novedad) -> Novedad:
        db.session.add(novedad)
        db.session.commit()
        return novedad
