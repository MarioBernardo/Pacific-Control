from app.extensions import db
from app.models.asistencia import Asistencia


class AsistenciaRepository:
    def get_by_id(self, asistencia_id: int) -> Asistencia | None:
        return db.session.get(Asistencia, asistencia_id)

    def get_all(self) -> list[Asistencia]:
        return db.session.execute(
            db.select(Asistencia).order_by(Asistencia.id_asistencia)
        ).scalars().all()

    def get_by_operation_id(self, operation_id: str) -> Asistencia | None:
        return db.session.execute(
            db.select(Asistencia).where(Asistencia.operation_id == operation_id)
        ).scalar_one_or_none()

    def save(self, asistencia: Asistencia) -> Asistencia:
        db.session.add(asistencia)
        db.session.commit()
        return asistencia
