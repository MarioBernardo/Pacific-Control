from flask import Blueprint, jsonify, request
from app.auth.authorization import cargo_required
from app.models.asistencia import Asistencia
from app.models.dispositivo import Dispositivo
from app.models.turno import Turno
from app.services.asistencia_service import AsistenciaService
from app.services.crud_utils import CrudConflictError, CrudValidationError
from app.services.query_service import paginated
from app.services.cache_service import cache_service
from sqlalchemy.orm import joinedload


asistencias_bp = Blueprint("asistencias", __name__, url_prefix="/asistencias")
asistencia_service = AsistenciaService()


def _serialize_asistencia(asistencia: Asistencia) -> dict:
    empleado = asistencia.empleado
    turno = asistencia.turno
    dispositivo = asistencia.dispositivo
    puesto = turno.puesto if turno else (dispositivo.puesto if dispositivo else None)
    return {
        "id_asistencia": asistencia.id_asistencia,
        "operation_id": asistencia.operation_id,
        "fecha_hora": asistencia.fecha_hora.isoformat(),
        "latitud": str(asistencia.latitud),
        "longitud": str(asistencia.longitud),
        "foto": asistencia.foto,
        "observacion": asistencia.observacion,
        "estado": asistencia.estado,
        "id_empleado": asistencia.id_empleado,
        "id_turno": asistencia.id_turno,
        "id_dispositivo": asistencia.id_dispositivo,
        "guardia": {"id_empleado": empleado.id_empleado, "nombre_completo": f"{empleado.apellidos} {empleado.nombres}", "cargo": empleado.cargo} if empleado else None,
        "turno": {"id_turno": turno.id_turno, "tipo_turno": turno.tipo_turno, "tipo_asignacion": turno.tipo_asignacion} if turno else None,
        "puesto": {"id_puesto": puesto.id_puesto, "nombre_puesto": puesto.nombre_puesto} if puesto else None,
        "dispositivo": {"id_dispositivo": dispositivo.id_dispositivo, "codigo_dispositivo": dispositivo.codigo_dispositivo} if dispositivo else None,
    }


def _payload():
    return request.get_json(silent=True)


@asistencias_bp.post("")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def create_asistencia():
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        asistencia = asistencia_service.create(payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    return jsonify({"data": _serialize_asistencia(asistencia)}), 201


@asistencias_bp.get("")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def list_asistencias():
    try: items, meta = paginated(Asistencia, filters={"estado": Asistencia.estado, "id_empleado": Asistencia.id_empleado, "id_turno": Asistencia.id_turno}, sort_fields={"id_asistencia": Asistencia.id_asistencia, "fecha_hora": Asistencia.fecha_hora}, options=(joinedload(Asistencia.empleado), joinedload(Asistencia.turno).joinedload(Turno.puesto), joinedload(Asistencia.dispositivo).joinedload(Dispositivo.puesto)))
    except CrudValidationError as error: return jsonify({"error": str(error), "detalles": error.errors}), 400
    return jsonify({"data": [_serialize_asistencia(item) for item in items], "meta": meta}), 200


@asistencias_bp.get("/<int:asistencia_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def get_asistencia(asistencia_id: int):
    data = cache_service.get_by_id(
        "asistencia", asistencia_id,
        lambda: asistencia_service.get_by_id(asistencia_id),
        _serialize_asistencia,
    )
    if data is None:
        return jsonify({"error": "Asistencia no encontrada."}), 404
    return jsonify({"data": data}), 200


@asistencias_bp.put("/<int:asistencia_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def update_asistencia(asistencia_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        asistencia = asistencia_service.update(asistencia_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    if asistencia is None:
        return jsonify({"error": "Asistencia no encontrada."}), 404
    return jsonify({"data": _serialize_asistencia(asistencia)}), 200


@asistencias_bp.patch("/<int:asistencia_id>/estado")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def change_asistencia_status(asistencia_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        asistencia = asistencia_service.change_status(asistencia_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    if asistencia is None:
        return jsonify({"error": "Asistencia no encontrada."}), 404
    return jsonify({"data": _serialize_asistencia(asistencia)}), 200
