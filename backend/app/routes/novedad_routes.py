from flask import Blueprint, jsonify, request

from app.models.novedad import Novedad
from app.services.crud_utils import CrudConflictError, CrudValidationError
from app.services.novedad_service import NovedadService


novedades_bp = Blueprint("novedades", __name__, url_prefix="/novedades")
novedad_service = NovedadService()


def _serialize_novedad(novedad: Novedad) -> dict:
    return {"id_novedad": novedad.id_novedad, "tipo": novedad.tipo, "descripcion": novedad.descripcion, "fecha_hora": novedad.fecha_hora.isoformat(), "estado": novedad.estado, "id_empleado": novedad.id_empleado, "id_turno": novedad.id_turno}


def _payload():
    return request.get_json(silent=True)


@novedades_bp.post("")
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
def list_novedades():
    return jsonify({"data": [_serialize_novedad(item) for item in novedad_service.get_all()]}), 200


@novedades_bp.get("/<int:novedad_id>")
def get_novedad(novedad_id: int):
    novedad = novedad_service.get_by_id(novedad_id)
    if novedad is None:
        return jsonify({"error": "Novedad no encontrada."}), 404
    return jsonify({"data": _serialize_novedad(novedad)}), 200


@novedades_bp.put("/<int:novedad_id>")
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
