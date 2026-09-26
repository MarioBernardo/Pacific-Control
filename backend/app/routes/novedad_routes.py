from flask import Blueprint, current_app, jsonify, request, send_file
from pathlib import Path
from app.auth.authorization import cargo_required
from app.models.novedad import Novedad
from app.models.dispositivo import Dispositivo
from app.models.turno import Turno
from app.services.crud_utils import CrudConflictError, CrudValidationError
from app.services.novedad_service import NovedadService
from app.services.query_service import paginated
from app.services.cache_service import cache_service
from sqlalchemy.orm import joinedload


novedades_bp = Blueprint("novedades", __name__, url_prefix="/novedades")
novedad_service = NovedadService()


def _serialize_novedad(novedad: Novedad) -> dict:
    empleado = novedad.empleado
    turno = novedad.turno
    dispositivo = novedad.dispositivo
    puesto = turno.puesto if turno else (dispositivo.puesto if dispositivo else None)
    return {"id_novedad": novedad.id_novedad, "operation_id": novedad.operation_id, "tipo": novedad.tipo, "descripcion": novedad.descripcion, "fecha_hora": novedad.fecha_hora.isoformat(), "estado": novedad.estado, "id_empleado": novedad.id_empleado, "id_turno": novedad.id_turno, "id_dispositivo": novedad.id_dispositivo, "evidencia_foto": novedad.evidencia_foto, "guardia": {"id_empleado": empleado.id_empleado, "nombre_completo": f"{empleado.apellidos} {empleado.nombres}"} if empleado else None, "turno": {"id_turno": turno.id_turno, "tipo_turno": turno.tipo_turno, "tipo_asignacion": turno.tipo_asignacion} if turno else None, "puesto": {"id_puesto": puesto.id_puesto, "nombre_puesto": puesto.nombre_puesto} if puesto else None, "dispositivo": {"id_dispositivo": dispositivo.id_dispositivo, "codigo_dispositivo": dispositivo.codigo_dispositivo} if dispositivo else None}


def _payload():
    return request.get_json(silent=True)


@novedades_bp.post("")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def create_novedad():
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        novedad = novedad_service.create(payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    return jsonify({"data": _serialize_novedad(novedad)}), 201


@novedades_bp.get("")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def list_novedades():
    try: items, meta = paginated(Novedad, filters={"estado": Novedad.estado, "tipo": Novedad.tipo, "id_empleado": Novedad.id_empleado, "id_turno": Novedad.id_turno}, sort_fields={"id_novedad": Novedad.id_novedad, "fecha_hora": Novedad.fecha_hora, "tipo": Novedad.tipo}, options=(joinedload(Novedad.empleado), joinedload(Novedad.turno).joinedload(Turno.puesto), joinedload(Novedad.dispositivo).joinedload(Dispositivo.puesto)))
    except CrudValidationError as error: return jsonify({"error": str(error), "detalles": error.errors}), 400
    return jsonify({"data": [_serialize_novedad(item) for item in items], "meta": meta}), 200


@novedades_bp.get("/<int:novedad_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def get_novedad(novedad_id: int):
    data = cache_service.get_by_id(
        "novedad", novedad_id,
        lambda: novedad_service.get_by_id(novedad_id),
        _serialize_novedad,
    )
    if data is None:
        return jsonify({"error": "Novedad no encontrada."}), 404
    return jsonify({"data": data}), 200


@novedades_bp.get("/<int:novedad_id>/evidencia")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def get_novedad_evidence(novedad_id: int):
    novedad = novedad_service.get_by_id(novedad_id)
    if novedad is None:
        return jsonify({"error": "Novedad no encontrada."}), 404
    if not novedad.evidencia_foto:
        return jsonify({"error": "La novedad no tiene evidencia fotográfica."}), 404
    root = Path(current_app.config["NOVEDAD_UPLOAD_FOLDER"]).resolve()
    path = (root / Path(novedad.evidencia_foto).name).resolve()
    if root not in path.parents or not path.is_file():
        return jsonify({"error": "Evidencia fotográfica no disponible."}), 404
    return send_file(path)


@novedades_bp.put("/<int:novedad_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def update_novedad(novedad_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        novedad = novedad_service.update(novedad_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    if novedad is None:
        return jsonify({"error": "Novedad no encontrada."}), 404
    return jsonify({"data": _serialize_novedad(novedad)}), 200


@novedades_bp.patch("/<int:novedad_id>/estado")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def change_novedad_status(novedad_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        novedad = novedad_service.change_status(novedad_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    if novedad is None:
        return jsonify({"error": "Novedad no encontrada."}), 404
    return jsonify({"data": _serialize_novedad(novedad)}), 200
