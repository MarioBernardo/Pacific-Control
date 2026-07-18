from app.extensions import db
from app.models.turno import Turno


class TurnoRepository:
    def get_by_id(self, turno_id: int) -> Turno | None:
        return db.session.get(Turno, turno_id)

    def get_all(self) -> list[Turno]:
        return db.session.execute(
            db.select(Turno).order_by(Turno.id_turno)
        ).scalars().all()

    def save(self, turno: Turno) -> Turno:
        db.session.add(turno)
        db.session.commit()
        return turno
