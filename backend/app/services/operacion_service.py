"""Operational device flow, separate from administrative JWT authentication."""
from datetime import date, datetime
from flask import current_app
from sqlalchemy.orm import joinedload
from werkzeug.security import check_password_hash
from app.extensions import cache, db
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.novedad import Novedad
from app.models.puesto import Puesto
from app.models.turno import Turno
from app.services.asistencia_service import AsistenciaService
from app.services.novedad_service import NovedadService

SESSION_TTL_SECONDS = 43200
_SESSION_KEY = "pacific-control:operacion:sesion:{device_id}"

class OperacionUnavailableError(Exception): pass
class OperacionAuthorizationError(Exception): pass

def _session_key(device_id): return _SESSION_KEY.format(device_id=device_id)

class OperacionService:
    def authenticate_device(self, device_id, token):
        device = db.session.get(Dispositivo, device_id)
        if device is None: return None
        if not device.token_operativo_hash:
            if not current_app.config.get("ALLOW_LEGACY_OPERATIVE_DEVICES", False):
                raise OperacionAuthorizationError("El dispositivo requiere aprovisionamiento operativo.")
        elif not token or not check_password_hash(device.token_operativo_hash, token):
            raise OperacionAuthorizationError("Credencial operativa inválida.")
        return device

    def get_device_info(self, device_id):
        device = db.session.get(Dispositivo, device_id)
        return None if device is None else self._serialize_device(device, db.session.get(Puesto, device.id_puesto))

    def get_device_by_codigo(self, codigo):
        device = db.session.execute(db.select(Dispositivo).where(Dispositivo.codigo_dispositivo == codigo)).scalar_one_or_none()
        return None if device is None else self._serialize_device(device, db.session.get(Puesto, device.id_puesto))

    def _valid_device(self, device_id):
        device = db.session.get(Dispositivo, device_id)
        if device is None or device.estado != "activo": return None
        puesto = db.session.get(Puesto, device.id_puesto)
        if puesto is None or puesto.estado != "activo": return None
        return device, puesto

    def _valid_turnos(self, device_id, empleado_id=None):
        valid = self._valid_device(device_id)
        if valid is None: return []
        statement = db.select(Turno).options(joinedload(Turno.empleado)).where(
            Turno.id_puesto == valid[0].id_puesto, Turno.estado == "activo", Turno.fecha == date.today()
        ).order_by(Turno.tipo_asignacion, Turno.id_turno)
        if empleado_id is not None: statement = statement.where(Turno.id_empleado == empleado_id)
        return list(db.session.execute(statement).scalars().all())

    def get_available_guards(self, device_id):
        if self._valid_device(device_id) is None: return None
        grouped = {}
        for turno in self._valid_turnos(device_id):
            empleado = turno.empleado
            if not empleado.estado or empleado.cargo != "GUARDIA": continue
            grouped.setdefault(empleado.id_empleado, (empleado, []) )[1].append(turno)
        return [self._serialize_available_guard(e, turnos) for e, turnos in grouped.values()]

    def get_session(self, device_id):
        valid = self._valid_device(device_id)
        if valid is None: return {"estado": "dispositivo_no_disponible"}
        device, puesto = valid
        raw = cache.get_json(_session_key(device_id))
        if raw is not None:
            guard = raw.get("guardia_identificado") or {}
            if any(t.id_turno == guard.get("id_turno") for t in self._valid_turnos(device_id, guard.get("id_empleado"))): return raw
            cache.delete(_session_key(device_id)); return self._base_session(device, puesto, "expirada")
        return self._base_session(device, puesto, "sin_identificar")

    def identify_guard(self, device_id, empleado_id, tipo_turno):
        valid = self._valid_device(device_id)
        if valid is None: return None
        device, puesto = valid
        empleado = db.session.get(Empleado, empleado_id)
        if empleado is None or not empleado.estado or empleado.cargo != "GUARDIA": return None
        turnos = [
            turno for turno in self._valid_turnos(device_id, empleado_id)
            if turno.tipo_turno == tipo_turno
        ]
        if not turnos: return None
        turno = turnos[0]
        data = {"dispositivo": self._serialize_device(device, puesto), "guardia_identificado": self._serialize_guard(empleado, turno), "estado": "identificado"}
        persisted = cache.set_json(_session_key(device_id), data, ttl=current_app.config.get("OPERATIVE_SESSION_TTL", SESSION_TTL_SECONDS))
        if device.token_operativo_hash and not persisted: raise OperacionUnavailableError("No fue posible persistir la sesión operativa.")
        return data

    def clear_session(self, device_id):
        if db.session.get(Dispositivo, device_id) is None: return False
        cache.delete(_session_key(device_id)); return True

    def create_attendance(self, device_id, payload):
        guard = self._required_session(device_id)["guardia_identificado"]
        return AsistenciaService().create({"fecha_hora": payload.get("fecha_hora", datetime.now().isoformat()), "latitud": payload.get("latitud"), "longitud": payload.get("longitud"), "foto": payload.get("foto"), "observacion": payload.get("observacion"), "estado": "registrada", "id_empleado": guard["id_empleado"], "id_turno": guard["id_turno"], "id_dispositivo": device_id})

    def create_incident(self, device_id, payload):
        guard = self._required_session(device_id)["guardia_identificado"]
        return NovedadService().create({"tipo": payload.get("tipo"), "descripcion": payload.get("descripcion"), "fecha_hora": payload.get("fecha_hora", datetime.now().isoformat()), "estado": "abierta", "id_empleado": guard["id_empleado"], "id_turno": guard["id_turno"]})

    def _required_session(self, device_id):
        session = self.get_session(device_id)
        if session.get("estado") != "identificado": raise OperacionAuthorizationError("No existe una sesión operativa válida.")
        return session

    @staticmethod
    def _base_session(device, puesto, estado): return {"dispositivo": OperacionService._serialize_device(device, puesto), "guardia_identificado": None, "estado": estado}
    @staticmethod
    def _serialize_device(d, p): return {"id_dispositivo": d.id_dispositivo, "codigo_dispositivo": d.codigo_dispositivo, "modelo": d.modelo, "estado": d.estado, "id_puesto": d.id_puesto, "puesto": {"id_puesto": p.id_puesto, "nombre_puesto": p.nombre_puesto, "direccion": p.direccion, "estado": p.estado} if p else None}
    @staticmethod
    def _serialize_guard(e, t): return {"id_empleado": e.id_empleado, "nombres": e.nombres, "apellidos": e.apellidos, "nombre_completo": f"{e.apellidos} {e.nombres}", "cargo": e.cargo, "tipo_asignacion": t.tipo_asignacion, "tipo_turno": t.tipo_turno, "id_turno": t.id_turno, "id_puesto": t.id_puesto}
    @staticmethod
    def _serialize_available_guard(e, turnos):
        first = turnos[0]
        return {
            "id_empleado": e.id_empleado,
            "nombres": e.nombres,
            "apellidos": e.apellidos,
            "nombre_completo": f"{e.apellidos} {e.nombres}",
            "cargo": e.cargo,
            "tipo_asignacion": first.tipo_asignacion,
            "id_puesto": first.id_puesto,
            "turnos_disponibles": [
                {"id_turno": turno.id_turno, "tipo_turno": turno.tipo_turno}
                for turno in sorted(turnos, key=lambda item: (item.tipo_turno, item.id_turno))
            ],
        }
