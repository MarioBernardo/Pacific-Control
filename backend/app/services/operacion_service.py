"""Operative session service.

Manages the temporary state of a guard identified on a device.
Uses Redis for session storage (TTL-based, no DB table needed).
Falls back gracefully when Redis is not available.

Security model:
- No JWT is required for operative endpoints.
- identify_guard() validates that the employee has an active turno
  at the device's puesto (FIJO or SACA_FRANCO) before accepting them.
- The session data returned never contains JWT tokens or admin credentials.
- Administrative endpoints remain independently protected by cargo_required.
"""

import logging
from typing import Any

from app.extensions import cache, db
from app.models.dispositivo import Dispositivo
from app.models.empleado import Empleado
from app.models.puesto import Puesto
from app.models.turno import Turno

logger = logging.getLogger(__name__)

# Session TTL: 12 hours (covers longest possible shift)
SESSION_TTL_SECONDS = 12 * 3600
_SESSION_KEY = "pacific-control:operacion:sesion:{device_id}"


def _session_key(device_id: int) -> str:
    return _SESSION_KEY.format(device_id=device_id)


class OperacionService:
    # ------------------------------------------------------------------
    # Device info
    # ------------------------------------------------------------------

    def get_device_info(self, device_id: int) -> dict | None:
        """Return device + puesto info, or None if device not found."""
        device = db.session.get(Dispositivo, device_id)
        if device is None:
            return None
        puesto = db.session.get(Puesto, device.id_puesto)
        return self._serialize_device(device, puesto)

    def get_device_by_codigo(self, codigo: str) -> dict | None:
        """Find a device by its string code and return device + puesto info."""
        device = db.session.execute(
            db.select(Dispositivo).where(Dispositivo.codigo_dispositivo == codigo)
        ).scalar_one_or_none()
        if device is None:
            return None
        puesto = db.session.get(Puesto, device.id_puesto)
        return self._serialize_device(device, puesto)

    # ------------------------------------------------------------------
    # Guards available for a device's puesto
    # ------------------------------------------------------------------

    def get_available_guards(self, device_id: int) -> list[dict] | None:
        """Return active guards for the puesto linked to the device.

        Returns None if device does not exist.
        Returns empty list if no active turnos found.
        Deduplicates by empleado (same guard can have multiple turnos;
        the first active one encountered takes precedence).
        """
        device = db.session.get(Dispositivo, device_id)
        if device is None:
            return None

        turnos: list[Turno] = db.session.execute(
            db.select(Turno)
            .where(Turno.id_puesto == device.id_puesto, Turno.estado == "activo")
            .order_by(Turno.tipo_asignacion, Turno.id_turno)
        ).scalars().all()

        result = []
        seen_empleado_ids: set[int] = set()
        for turno in turnos:
            if turno.id_empleado in seen_empleado_ids:
                continue
            seen_empleado_ids.add(turno.id_empleado)
            empleado = db.session.get(Empleado, turno.id_empleado)
            if empleado is None or not empleado.estado:
                continue
            result.append(self._serialize_guard(empleado, turno))
        return result

    # ------------------------------------------------------------------
    # Operative session (Redis-backed, falls back silently)
    # ------------------------------------------------------------------

    def get_session(self, device_id: int) -> dict:
        """Return current operative session for a device.

        If Redis has a stored session it is returned directly.
        Otherwise builds a base session with estado='sin_identificar'.
        Returns {'estado': 'dispositivo_no_encontrado'} when device is missing.
        """
        key = _session_key(device_id)
        raw = cache.get_json(key)
        if raw is not None:
            return raw

        device = db.session.get(Dispositivo, device_id)
        if device is None:
            return {"estado": "dispositivo_no_encontrado"}
        puesto = db.session.get(Puesto, device.id_puesto)
        return {
            "dispositivo": self._serialize_device(device, puesto),
            "guardia_identificado": None,
            "estado": "sin_identificar",
        }

    def identify_guard(self, device_id: int, empleado_id: int) -> dict | None:
        """Set the identified guard for a device session.

        Validates:
        1. Device exists.
        2. Employee exists and is active.
        3. Employee has an active turno at the device's puesto
           (either FIJO or SACA_FRANCO — both are valid assignments).

        Returns the session dict on success, None otherwise.
        This method does NOT issue any credentials or tokens.
        """
        device = db.session.get(Dispositivo, device_id)
        if device is None:
            return None

        empleado = db.session.get(Empleado, empleado_id)
        if empleado is None or not empleado.estado:
            return None

        puesto = db.session.get(Puesto, device.id_puesto)

        # Employee must have an active turno at this puesto
        turno = db.session.execute(
            db.select(Turno).where(
                Turno.id_empleado == empleado_id,
                Turno.id_puesto == device.id_puesto,
                Turno.estado == "activo",
            )
        ).scalar_one_or_none()

        if turno is None:
            # Employee not assigned to this puesto — deny identification
            return None

        session_data: dict[str, Any] = {
            "dispositivo": self._serialize_device(device, puesto),
            "guardia_identificado": {
                "id_empleado": empleado.id_empleado,
                "nombres": empleado.nombres,
                "apellidos": empleado.apellidos,
                "nombre_completo": f"{empleado.apellidos} {empleado.nombres}",
                "cargo": empleado.cargo,
                "tipo_asignacion": turno.tipo_asignacion,
                "tipo_turno": turno.tipo_turno,
                "id_turno": turno.id_turno,
            },
            "estado": "identificado",
        }

        key = _session_key(device_id)
        try:
            cache.set_json(key, session_data)
        except Exception:
            logger.warning("No se pudo persistir la sesión operativa en Redis.")

        return session_data

    def clear_session(self, device_id: int) -> bool:
        """Remove the identified guard from a device session."""
        device = db.session.get(Dispositivo, device_id)
        if device is None:
            return False
        key = _session_key(device_id)
        cache.delete(key)
        return True

    # ------------------------------------------------------------------
    # Serialization helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _serialize_device(device: Dispositivo, puesto: Puesto | None) -> dict:
        return {
            "id_dispositivo": device.id_dispositivo,
            "codigo_dispositivo": device.codigo_dispositivo,
            "modelo": device.modelo,
            "estado": device.estado,
            "id_puesto": device.id_puesto,
            "puesto": {
                "id_puesto": puesto.id_puesto,
                "nombre_puesto": puesto.nombre_puesto,
                "direccion": puesto.direccion,
                "estado": puesto.estado,
            } if puesto else None,
        }

    @staticmethod
    def _serialize_guard(empleado: Empleado, turno: Turno) -> dict:
        return {
            "id_empleado": empleado.id_empleado,
            "nombres": empleado.nombres,
            "apellidos": empleado.apellidos,
            "nombre_completo": f"{empleado.apellidos} {empleado.nombres}",
            "cargo": empleado.cargo,
            "tipo_asignacion": turno.tipo_asignacion,
            "tipo_turno": turno.tipo_turno,
            "id_turno": turno.id_turno,
            "id_puesto": turno.id_puesto,
        }
