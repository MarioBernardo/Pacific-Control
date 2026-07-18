from app.extensions import db
from app.models.novedad import Novedad


class NovedadRepository:
    def get_by_id(self, novedad_id: int) -> Novedad | None:
        return db.session.get(Novedad, novedad_id)

    def get_all(self) -> list[Novedad]:
        return db.session.execute(
            db.select(Novedad).order_by(Novedad.id_novedad)
        ).scalars().all()

    def save(self, novedad: Novedad) -> Novedad:
        db.session.add(novedad)
        db.session.commit()
        return novedad
