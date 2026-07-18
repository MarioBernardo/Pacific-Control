from flask import Blueprint, jsonify, request

from app.models.empleado import Empleado
from app.services.empleado_service import (
    EmpleadoConflictError,
    EmpleadoService,
    EmpleadoValidationError,
)


empleados_bp = Blueprint("empleados", __name__, url_prefix="/empleados")
empleado_service = EmpleadoService()


def _serialize_empleado(empleado: Empleado) -> dict:
    return {
        "id_empleado": empleado.id_empleado,
        "cedula": empleado.cedula,
        "nombres": empleado.nombres,
        "apellidos": empleado.apellidos,
        "correo": empleado.correo,
        "telefono": empleado.telefono,
        "cargo": empleado.cargo,
        "estado": empleado.estado,
    }


def _json_payload() -> dict | None:
    return request.get_json(silent=True)


@empleados_bp.post("")
def create_empleado():
    payload = _json_payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400

    try:
        empleado = empleado_service.create(payload)
    except EmpleadoValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except EmpleadoConflictError as error:
        return jsonify({"error": str(error)}), 409

    return jsonify({"data": _serialize_empleado(empleado)}), 201


@empleados_bp.get("")
def list_empleados():
    empleados = empleado_service.get_all()
    return jsonify({"data": [_serialize_empleado(empleado) for empleado in empleados]}), 200


@empleados_bp.get("/<int:empleado_id>")
def get_empleado(empleado_id: int):
    empleado = empleado_service.get_by_id(empleado_id)
    if empleado is None:
        return jsonify({"error": "Empleado no encontrado."}), 404

    return jsonify({"data": _serialize_empleado(empleado)}), 200


@empleados_bp.put("/<int:empleado_id>")
def update_empleado(empleado_id: int):
    payload = _json_payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400

    try:
        empleado = empleado_service.update(empleado_id, payload)
    except EmpleadoValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except EmpleadoConflictError as error:
        return jsonify({"error": str(error)}), 409

    if empleado is None:
        return jsonify({"error": "Empleado no encontrado."}), 404

    return jsonify({"data": _serialize_empleado(empleado)}), 200


@empleados_bp.patch("/<int:empleado_id>/estado")
def change_empleado_status(empleado_id: int):
    payload = _json_payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400

    try:
        empleado = empleado_service.change_status(empleado_id, payload)
    except EmpleadoValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400

    if empleado is None:
        return jsonify({"error": "Empleado no encontrado."}), 404

    return jsonify({"data": _serialize_empleado(empleado)}), 200
