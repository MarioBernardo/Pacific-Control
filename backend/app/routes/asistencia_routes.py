from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required

from app.models.asistencia import Asistencia
from app.services.asistencia_service import AsistenciaService
from app.services.crud_utils import CrudConflictError, CrudValidationError


asistencias_bp = Blueprint("asistencias", __name__, url_prefix="/asistencias")
asistencia_service = AsistenciaService()


def _serialize_asistencia(asistencia: Asistencia) -> dict:
    return {"id_asistencia": asistencia.id_asistencia, "fecha_hora": asistencia.fecha_hora.isoformat(), "latitud": str(asistencia.latitud), "longitud": str(asistencia.longitud), "foto": asistencia.foto, "observacion": asistencia.observacion, "estado": asistencia.estado, "id_empleado": asistencia.id_empleado, "id_turno": asistencia.id_turno, "id_dispositivo": asistencia.id_dispositivo}


def _payload():
    return request.get_json(silent=True)


@asistencias_bp.post("")
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
@jwt_required()
def list_asistencias():
    return jsonify({"data": [_serialize_asistencia(item) for item in asistencia_service.get_all()]}), 200


@asistencias_bp.get("/<int:asistencia_id>")
@jwt_required()
def get_asistencia(asistencia_id: int):
    asistencia = asistencia_service.get_by_id(asistencia_id)
    if asistencia is None:
        return jsonify({"error": "Asistencia no encontrada."}), 404
    return jsonify({"data": _serialize_asistencia(asistencia)}), 200


@asistencias_bp.put("/<int:asistencia_id>")
@jwt_required()
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
@jwt_required()
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
