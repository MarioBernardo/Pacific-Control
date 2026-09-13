"""Operative device routes.

Provides the REST endpoints for the guard identification flow:

  GET  /operacion/dispositivos/<id>                  → device + puesto info
  GET  /operacion/dispositivos/codigo/<codigo>       → device by string code
  GET  /operacion/dispositivos/<id>/guardias         → available guards for puesto
  GET  /operacion/dispositivos/<id>/sesion           → current session
  POST /operacion/dispositivos/<id>/sesion/identificar → identify guard
  DELETE /operacion/dispositivos/<id>/sesion         → clear identified guard

All endpoints require a valid JWT (any active employee).
They do NOT grant administrative capabilities — they only expose
the operative state of a device's session.
"""

from flask import Blueprint, jsonify, request

from app.auth.authorization import active_employee_required
from app.services.operacion_service import OperacionService

operacion_bp = Blueprint("operacion", __name__, url_prefix="/operacion")
_service = OperacionService()


@operacion_bp.get("/dispositivos/<int:device_id>")
@active_employee_required
def get_device(device_id: int):
    """Return device info including its associated puesto."""
    info = _service.get_device_info(device_id)
    if info is None:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": info}), 200


@operacion_bp.get("/dispositivos/codigo/<string:codigo>")
@active_employee_required
def get_device_by_codigo(codigo: str):
    """Find device by its code (e.g. BAVIERA-01)."""
    info = _service.get_device_by_codigo(codigo)
    if info is None:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": info}), 200


@operacion_bp.get("/dispositivos/<int:device_id>/guardias")
@active_employee_required
def list_guards(device_id: int):
    """Return active guards available for the puesto linked to this device."""
    guards = _service.get_available_guards(device_id)
    if guards is None:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": guards}), 200


@operacion_bp.get("/dispositivos/<int:device_id>/sesion")
@active_employee_required
def get_session(device_id: int):
    """Return the current operative session for a device."""
    session = _service.get_session(device_id)
    if session.get("estado") == "dispositivo_no_encontrado":
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": session}), 200


@operacion_bp.post("/dispositivos/<int:device_id>/sesion/identificar")
@active_employee_required
def identify_guard(device_id: int):
    """Identify the guard operating at a device.

    Body: {"id_empleado": <int>}
    """
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400

    empleado_id = payload.get("id_empleado")
    if not isinstance(empleado_id, int) or isinstance(empleado_id, bool) or empleado_id <= 0:
        return jsonify({"error": "id_empleado debe ser un entero positivo."}), 400

    session = _service.identify_guard(device_id, empleado_id)
    if session is None:
        return jsonify({"error": "Dispositivo o empleado no encontrado, o empleado inactivo."}), 404
    return jsonify({"data": session}), 200


@operacion_bp.delete("/dispositivos/<int:device_id>/sesion")
@active_employee_required
def clear_session(device_id: int):
    """Remove the identified guard from a device session."""
    ok = _service.clear_session(device_id)
    if not ok:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": {"mensaje": "Sesión operativa limpiada."}}), 200
