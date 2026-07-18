from app.extensions import db
from app.models.puesto import Puesto


class PuestoRepository:
    def get_by_id(self, puesto_id: int) -> Puesto | None:
        return db.session.get(Puesto, puesto_id)

    def get_all(self) -> list[Puesto]:
        return db.session.execute(
            db.select(Puesto).order_by(Puesto.id_puesto)
        ).scalars().all()

    def save(self, puesto: Puesto) -> Puesto:
        db.session.add(puesto)
        db.session.commit()
        return puesto
