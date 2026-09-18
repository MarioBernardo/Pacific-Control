"""Operative device routes.

Provides the REST endpoints for the guard identification flow:

  GET  /operacion/dispositivos/<id>                    → device + puesto info
  GET  /operacion/dispositivos/codigo/<codigo>         → device by string code
  GET  /operacion/dispositivos/<id>/guardias           → available guards for puesto
  GET  /operacion/dispositivos/<id>/sesion             → current session
  POST /operacion/dispositivos/<id>/sesion/identificar → identify guard
  DELETE /operacion/dispositivos/<id>/sesion           → clear identified guard

These endpoints are INTENTIONALLY unauthenticated (no JWT required).
They represent the operative layer used directly from a physical device
at a post/building. Authentication here is implicit via the physical
device code associated with a puesto — not via admin credentials.

Security guarantees:
- These endpoints NEVER expose administrative capabilities.
- They only allow guard identification within an existing device session.
- Identifying a guard does NOT grant JWT tokens or any administrative access.
- All modifications to employees, puestos, dispositivos or turnos remain
  protected by JWT + cargo_required on their own blueprints.
"""

from flask import Blueprint, jsonify, request

from app.services.operacion_service import OperacionService, OperacionAuthorizationError, OperacionUnavailableError
from app.services.crud_utils import CrudValidationError, CrudConflictError
from app.routes.asistencia_routes import _serialize_asistencia
from app.routes.novedad_routes import _serialize_novedad

operacion_bp = Blueprint("operacion", __name__, url_prefix="/operacion")
_service = OperacionService()

def _authorize(device_id):
    try:
        device = _service.authenticate_device(device_id, request.headers.get("X-Device-Token"))
    except OperacionAuthorizationError as error:
        return None, (jsonify({"error": str(error)}), 401)
    if device is None:
        return None, (jsonify({"error": "Dispositivo no encontrado."}), 404)
    return device, None


@operacion_bp.get("/dispositivos/<int:device_id>")
def get_device(device_id: int):
    _, error = _authorize(device_id)
    if error: return error
    """Return device info including its associated puesto."""
    info = _service.get_device_info(device_id)
    if info is None:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": info}), 200


@operacion_bp.get("/dispositivos/codigo/<string:codigo>")
def get_device_by_codigo(codigo: str):
    """Find device by its code (e.g. BAVIERA-01)."""
    info = _service.get_device_by_codigo(codigo)
    if info is None:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": info}), 200


@operacion_bp.get("/dispositivos/<int:device_id>/guardias")
def list_guards(device_id: int):
    _, error = _authorize(device_id)
    if error: return error
    """Return active guards available for the puesto linked to this device."""
    guards = _service.get_available_guards(device_id)
    if guards is None:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": guards}), 200


@operacion_bp.get("/dispositivos/<int:device_id>/sesion")
def get_session(device_id: int):
    _, error = _authorize(device_id)
    if error: return error
    """Return the current operative session for a device."""
    session = _service.get_session(device_id)
    if session.get("estado") == "dispositivo_no_disponible":
        return jsonify({"error": "Dispositivo o puesto no disponible."}), 409
    return jsonify({"data": session}), 200


@operacion_bp.post("/dispositivos/<int:device_id>/sesion/identificar")
def identify_guard(device_id: int):
    _, error = _authorize(device_id)
    if error: return error
    """Identify the guard operating at a device.

    Body: {"id_empleado": <int>}

    Validates:
    - device exists
    - employee exists and is active
    - employee has an active turno at the device's puesto (FIJO or SACA_FRANCO)
    """
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400

    empleado_id = payload.get("id_empleado")
    if not isinstance(empleado_id, int) or isinstance(empleado_id, bool) or empleado_id <= 0:
        return jsonify({"error": "id_empleado debe ser un entero positivo."}), 400

    try:
        result = _service.identify_guard(device_id, empleado_id)
    except OperacionUnavailableError as error:
        return jsonify({"error": str(error)}), 503

    if result is None:
        return jsonify({"error": "Dispositivo no encontrado, empleado no encontrado, inactivo, o no asignado a este puesto."}), 404

    return jsonify({"data": result}), 200


@operacion_bp.delete("/dispositivos/<int:device_id>/sesion")
def clear_session(device_id: int):
    _, error = _authorize(device_id)
    if error: return error
    """Remove the identified guard from a device session."""
    ok = _service.clear_session(device_id)
    if not ok:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": {"mensaje": "Sesión operativa limpiada."}}), 200

@operacion_bp.post("/dispositivos/<int:device_id>/asistencias")
def create_operational_attendance(device_id: int):
    _, error = _authorize(device_id)
    if error: return error
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict): return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        item = _service.create_attendance(device_id, payload)
    except OperacionAuthorizationError as exc: return jsonify({"error": str(exc)}), 401
    except CrudValidationError as exc: return jsonify({"error": str(exc), "detalles": exc.errors}), 400
    except CrudConflictError as exc: return jsonify({"error": str(exc)}), 409
    return jsonify({"data": _serialize_asistencia(item)}), 201

@operacion_bp.post("/dispositivos/<int:device_id>/novedades")
def create_operational_incident(device_id: int):
    _, error = _authorize(device_id)
    if error: return error
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict): return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        item = _service.create_incident(device_id, payload)
    except OperacionAuthorizationError as exc: return jsonify({"error": str(exc)}), 401
    except CrudValidationError as exc: return jsonify({"error": str(exc), "detalles": exc.errors}), 400
    except CrudConflictError as exc: return jsonify({"error": str(exc)}), 409
    return jsonify({"data": _serialize_novedad(item)}), 201
