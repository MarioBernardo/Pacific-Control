from calendar import monthrange
from datetime import datetime, timedelta

from sqlalchemy.orm import joinedload

from app.extensions import db
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.turno import Turno


INVALID_ATTENDANCE_STATES = {"anulada", "cancelada", "inactiva"}


def _duration_hours(tipo_turno: str) -> int:
    return 12 if tipo_turno == "12 HORAS" else 24 if tipo_turno == "24 HORAS" else 0


def _attendance_data(item: Asistencia) -> dict:
    turno = item.turno
    puesto = turno.puesto
    return {
        "id_asistencia": item.id_asistencia,
        "guardia": f"{item.empleado.apellidos} {item.empleado.nombres}",
        "id_empleado": item.id_empleado,
        "puesto": puesto.nombre_puesto,
        "id_puesto": puesto.id_puesto,
        "tipo_turno": turno.tipo_turno,
        "tipo_asignacion": turno.tipo_asignacion,
        "fecha_hora": item.fecha_hora.isoformat(),
        "estado": item.estado,
        "tiene_ubicacion": item.latitud is not None and item.longitud is not None,
    }


class ReportService:
    @staticmethod
    def _base_attendance_statement():
        return db.select(Asistencia).options(
            joinedload(Asistencia.empleado),
            joinedload(Asistencia.turno).joinedload(Turno.puesto),
            joinedload(Asistencia.dispositivo),
        )

    def personnel_on_shift(self, now: datetime | None = None) -> list[dict]:
        now = now or datetime.now()
        candidates = db.session.execute(
            self._base_attendance_statement()
            .where(Asistencia.fecha_hora <= now)
            .order_by(Asistencia.fecha_hora.desc(), Asistencia.id_asistencia.desc())
        ).scalars().all()
        active_by_guard = {}
        seen_guards = set()
        for item in candidates:
            if item.estado.lower() in INVALID_ATTENDANCE_STATES or item.id_empleado in seen_guards:
                continue
            seen_guards.add(item.id_empleado)
            hours = _duration_hours(item.turno.tipo_turno)
            if not hours:
                continue
            ends_at = item.fecha_hora + timedelta(hours=hours)
            if now < ends_at:
                data = _attendance_data(item)
                data["finalizacion_estimada"] = ends_at.isoformat()
                active_by_guard[item.id_empleado] = data
        return list(active_by_guard.values())

    def dashboard(self, now: datetime | None = None) -> dict:
        now = now or datetime.now()
        start = datetime.combine(now.date(), datetime.min.time())
        end = start + timedelta(days=1)
        personnel = self.personnel_on_shift(now)
        attendances_today = db.session.scalar(
            db.select(db.func.count(Asistencia.id_asistencia)).where(
                Asistencia.fecha_hora >= start,
                Asistencia.fecha_hora < end,
                db.func.lower(Asistencia.estado).not_in(INVALID_ATTENDANCE_STATES),
            )
        )
        open_incidents = db.session.scalar(
            db.select(db.func.count(Novedad.id_novedad)).where(
                db.func.lower(Novedad.estado).in_(("abierta", "pendiente"))
            )
        )
        return {
            "guardias_en_turno": len(personnel),
            "asistencias_hoy": attendances_today or 0,
            "novedades_abiertas": open_incidents or 0,
            "puestos_con_personal": len({item["id_puesto"] for item in personnel}),
            "personal_en_turno": personnel[:5],
        }

    def monthly_summary(self, employee_id: int, month: int, year: int) -> dict:
        start = datetime(year, month, 1)
        end = datetime(year, month, monthrange(year, month)[1]) + timedelta(days=1)
        items = db.session.execute(
            self._base_attendance_statement().where(
                Asistencia.id_empleado == employee_id,
                Asistencia.fecha_hora >= start,
                Asistencia.fecha_hora < end,
                db.func.lower(Asistencia.estado).not_in(INVALID_ATTENDANCE_STATES),
            ).order_by(Asistencia.fecha_hora.desc())
        ).scalars().all()
        twelve = sum(item.turno.tipo_turno == "12 HORAS" for item in items)
        twenty_four = sum(item.turno.tipo_turno == "24 HORAS" for item in items)
        incidents = db.session.scalar(
            db.select(db.func.count(Novedad.id_novedad)).where(
                Novedad.id_empleado == employee_id,
                Novedad.fecha_hora >= start,
                Novedad.fecha_hora < end,
            )
        ) or 0
        employee = items[0].empleado if items else db.session.get(Empleado, employee_id)
        return {
            "id_empleado": employee_id,
            "guardia": f"{employee.apellidos} {employee.nombres}" if employee else None,
            "mes": month,
            "anio": year,
            "total_turnos": len(items),
            "turnos_12_horas": twelve,
            "turnos_24_horas": twenty_four,
            "horas_derivadas": twelve * 12 + twenty_four * 24,
            "asistencias": len(items),
            "puestos": sorted({item.turno.puesto.nombre_puesto for item in items}),
            "novedades": incidents,
            "historial": [_attendance_data(item) for item in items],
        }
