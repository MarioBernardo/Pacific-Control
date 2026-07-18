from flask import Blueprint, jsonify, request

from app.models.turno import Turno
from app.services.crud_utils import CrudConflictError, CrudValidationError
from app.services.turno_service import TurnoService


turnos_bp = Blueprint("turnos", __name__, url_prefix="/turnos")
turno_service = TurnoService()


def _serialize_turno(turno: Turno) -> dict:
    return {"id_turno": turno.id_turno, "fecha": turno.fecha.isoformat(), "hora_inicio": turno.hora_inicio.isoformat(), "hora_fin": turno.hora_fin.isoformat(), "estado": turno.estado, "id_empleado": turno.id_empleado, "id_puesto": turno.id_puesto}


def _payload():
    return request.get_json(silent=True)


@turnos_bp.post("")
def create_turno():
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        turno = turno_service.create(payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    return jsonify({"data": _serialize_turno(turno)}), 201


@turnos_bp.get("")
def list_turnos():
    return jsonify({"data": [_serialize_turno(item) for item in turno_service.get_all()]}), 200


@turnos_bp.get("/<int:turno_id>")
def get_turno(turno_id: int):
    turno = turno_service.get_by_id(turno_id)
    if turno is None:
        return jsonify({"error": "Turno no encontrado."}), 404
    return jsonify({"data": _serialize_turno(turno)}), 200


@turnos_bp.put("/<int:turno_id>")
def update_turno(turno_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        turno = turno_service.update(turno_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    if turno is None:
        return jsonify({"error": "Turno no encontrado."}), 404
    return jsonify({"data": _serialize_turno(turno)}), 200


@turnos_bp.patch("/<int:turno_id>/estado")
def change_turno_status(turno_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        turno = turno_service.change_status(turno_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    if turno is None:
        return jsonify({"error": "Turno no encontrado."}), 404
    return jsonify({"data": _serialize_turno(turno)}), 200
