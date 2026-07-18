from app.extensions import db
from app.models.empleado import Empleado


class EmpleadoRepository:
    def get_by_id(self, empleado_id: int) -> Empleado | None:
        return db.session.get(Empleado, empleado_id)

    def get_all(self) -> list[Empleado]:
        return db.session.execute(
            db.select(Empleado).order_by(Empleado.id_empleado)
        ).scalars().all()

    def get_by_cedula(self, cedula: str) -> Empleado | None:
        return db.session.execute(
            db.select(Empleado).where(Empleado.cedula == cedula)
        ).scalar_one_or_none()

    def get_by_correo(self, correo: str) -> Empleado | None:
        return db.session.execute(
            db.select(Empleado).where(Empleado.correo == correo)
        ).scalar_one_or_none()

    def save(self, empleado: Empleado) -> Empleado:
        db.session.add(empleado)
        db.session.commit()
        return empleado
