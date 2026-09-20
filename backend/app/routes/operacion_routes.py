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

from flask import Blueprint, current_app, jsonify, request
from pathlib import Path
import uuid

from app.services.operacion_service import OperacionService, OperacionAuthorizationError, OperacionUnavailableError
from app.services.turno_service import VALID_TIPO_TURNO
from app.services.crud_utils import CrudValidationError, CrudConflictError
from app.routes.asistencia_routes import _serialize_asistencia
from app.routes.novedad_routes import _serialize_novedad

operacion_bp = Blueprint("operacion", __name__, url_prefix="/operacion")
_service = OperacionService()

def _authorize(device_id):
    try:
        device = _service.authenticate_device(
            device_id, request.headers.get("X-Device-Token"), request.headers.get("X-Device-Session")
        )
    except OperacionAuthorizationError as error:
        return None, (jsonify({"error": str(error)}), 401)
    if device is None:
        return None, (jsonify({"error": "Dispositivo no encontrado."}), 404)
    return device, None


@operacion_bp.post("/login")
def login_device():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        result = _service.login_device(payload.get("usuario"), payload.get("password"))
    except OperacionAuthorizationError as error:
        return jsonify({"error": str(error)}), 401
    except OperacionUnavailableError as error:
        return jsonify({"error": str(error)}), 503
    return jsonify({"data": result}), 200


@operacion_bp.post("/dispositivos/<int:device_id>/logout")
def logout_device(device_id):
    try:
        _service.logout_device(device_id, request.headers.get("X-Device-Session"))
    except OperacionAuthorizationError as error:
        return jsonify({"error": str(error)}), 401
    return jsonify({"data": {"mensaje": "Sesión del dispositivo cerrada."}}), 200


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

    Body: {"id_empleado": <int>, "tipo_turno": "12 HORAS" | "24 HORAS"}

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
    tipo_turno = payload.get("tipo_turno")
    if tipo_turno not in VALID_TIPO_TURNO:
        return jsonify({"error": "tipo_turno debe ser 12 HORAS o 24 HORAS."}), 400

    try:
        result = _service.identify_guard(device_id, empleado_id, tipo_turno)
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


@operacion_bp.post("/dispositivos/<int:device_id>/novedades-con-foto")
def create_operational_incident_with_photo(device_id: int):
    _, error = _authorize(device_id)
    if error: return error
    photo = request.files.get("foto")
    saved_path = None
    try:
        payload = {"tipo": request.form.get("tipo"), "descripcion": request.form.get("descripcion")}
        if photo and photo.filename:
            content = photo.read(current_app.config["MAX_NOVEDAD_PHOTO_BYTES"] + 1)
            if len(content) > current_app.config["MAX_NOVEDAD_PHOTO_BYTES"]:
                return jsonify({"error": "La fotografía supera el límite de 5 MB."}), 413
            kind = (
                "jpeg" if content.startswith(b"\xff\xd8\xff")
                else "png" if content.startswith(b"\x89PNG\r\n\x1a\n")
                else None
            )
            if kind not in {"jpeg", "png"}:
                return jsonify({"error": "La evidencia debe ser una imagen JPEG o PNG válida."}), 400
            extension = ".jpg" if kind == "jpeg" else ".png"
            folder = Path(current_app.config["NOVEDAD_UPLOAD_FOLDER"]).resolve()
            folder.mkdir(parents=True, exist_ok=True)
            filename = f"{uuid.uuid4().hex}{extension}"
            saved_path = folder / filename
            saved_path.write_bytes(content)
            payload["evidencia_foto"] = f"uploads/novedades/{filename}"
        item = _service.create_incident(device_id, payload)
        return jsonify({"data": _serialize_novedad(item)}), 201
    except OperacionAuthorizationError as exc: return jsonify({"error": str(exc)}), 401
    except CrudValidationError as exc:
        if saved_path: saved_path.unlink(missing_ok=True)
        return jsonify({"error": str(exc), "detalles": exc.errors}), 400
    except CrudConflictError as exc:
        if saved_path: saved_path.unlink(missing_ok=True)
        return jsonify({"error": str(exc)}), 409
