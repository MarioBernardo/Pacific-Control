from flask import Blueprint, jsonify, request
from app.auth.authorization import cargo_required
from app.models.dispositivo import Dispositivo
from app.services.crud_utils import CrudConflictError, CrudValidationError
from app.services.dispositivo_service import DispositivoService
from app.services.query_service import paginated
from app.services.cache_service import cache_service
from sqlalchemy.orm import joinedload


dispositivos_bp = Blueprint("dispositivos", __name__, url_prefix="/dispositivos")
dispositivo_service = DispositivoService()


def _serialize_dispositivo(dispositivo: Dispositivo) -> dict:
    return {"id_dispositivo": dispositivo.id_dispositivo, "codigo_dispositivo": dispositivo.codigo_dispositivo, "modelo": dispositivo.modelo, "estado": dispositivo.estado, "id_puesto": dispositivo.id_puesto, "puesto": {"id_puesto": dispositivo.puesto.id_puesto, "nombre_puesto": dispositivo.puesto.nombre_puesto}}


def _payload():
    return request.get_json(silent=True)


@dispositivos_bp.post("")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def create_dispositivo():
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        dispositivo = dispositivo_service.create(payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    return jsonify({"data": _serialize_dispositivo(dispositivo)}), 201


@dispositivos_bp.get("")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def list_dispositivos():
    try: items, meta = paginated(Dispositivo, filters={"estado": Dispositivo.estado, "id_puesto": Dispositivo.id_puesto}, search_columns=(Dispositivo.codigo_dispositivo,), sort_fields={"id_dispositivo": Dispositivo.id_dispositivo, "codigo_dispositivo": Dispositivo.codigo_dispositivo}, options=(joinedload(Dispositivo.puesto),))
    except CrudValidationError as error: return jsonify({"error": str(error), "detalles": error.errors}), 400
    return jsonify({"data": [_serialize_dispositivo(item) for item in items], "meta": meta}), 200


@dispositivos_bp.get("/<int:dispositivo_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def get_dispositivo(dispositivo_id: int):
    data = cache_service.get_by_id(
        "dispositivo", dispositivo_id,
        lambda: dispositivo_service.get_by_id(dispositivo_id),
        _serialize_dispositivo,
    )
    if data is None:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": data}), 200


@dispositivos_bp.put("/<int:dispositivo_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def update_dispositivo(dispositivo_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        dispositivo = dispositivo_service.update(dispositivo_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    if dispositivo is None:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": _serialize_dispositivo(dispositivo)}), 200


@dispositivos_bp.patch("/<int:dispositivo_id>/estado")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def change_dispositivo_status(dispositivo_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        dispositivo = dispositivo_service.change_status(dispositivo_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    if dispositivo is None:
        return jsonify({"error": "Dispositivo no encontrado."}), 404
    return jsonify({"data": _serialize_dispositivo(dispositivo)}), 200
