from app.extensions import db
from app.models.turno import Turno


class TurnoRepository:
    def get_by_id(self, turno_id: int) -> Turno | None:
        return db.session.get(Turno, turno_id)

    def get_all(self) -> list[Turno]:
        return db.session.execute(
            db.select(Turno).order_by(Turno.id_turno)
        ).scalars().all()

    def get_active_by_puesto(self, puesto_id: int) -> list[Turno]:
        """Active turnos for a puesto, ordered FIJO first then SACA_FRANCO."""
        return db.session.execute(
            db.select(Turno)
            .where(Turno.id_puesto == puesto_id, Turno.estado == "activo")
            .order_by(Turno.tipo_asignacion, Turno.id_turno)
        ).scalars().all()

    def get_by_puesto(self, puesto_id: int) -> list[Turno]:
        """All turnos for a puesto regardless of status."""
        return db.session.execute(
            db.select(Turno)
            .where(Turno.id_puesto == puesto_id)
            .order_by(Turno.tipo_asignacion, Turno.id_turno)
        ).scalars().all()

    def save(self, turno: Turno) -> Turno:
        db.session.add(turno)
        db.session.commit()
        return turno
