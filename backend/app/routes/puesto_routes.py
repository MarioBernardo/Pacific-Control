from flask import Blueprint, jsonify, request
from app.auth.authorization import cargo_required
from app.models.puesto import Puesto
from app.services.crud_utils import CrudConflictError, CrudValidationError
from app.services.query_service import paginated
from app.services.puesto_service import PuestoService


puestos_bp = Blueprint("puestos", __name__, url_prefix="/puestos")
puesto_service = PuestoService()


def _serialize_puesto(puesto: Puesto) -> dict:
    return {"id_puesto": puesto.id_puesto, "nombre_puesto": puesto.nombre_puesto, "direccion": puesto.direccion, "estado": puesto.estado}


def _payload():
    return request.get_json(silent=True)


@puestos_bp.post("")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def create_puesto():
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        puesto = puesto_service.create(payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    return jsonify({"data": _serialize_puesto(puesto)}), 201


@puestos_bp.get("")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def list_puestos():
    try: items, meta = paginated(Puesto, filters={"estado": Puesto.estado}, search_columns=(Puesto.nombre_puesto, Puesto.direccion), sort_fields={"id_puesto": Puesto.id_puesto, "nombre_puesto": Puesto.nombre_puesto})
    except CrudValidationError as error: return jsonify({"error": str(error), "detalles": error.errors}), 400
    return jsonify({"data": [_serialize_puesto(item) for item in items], "meta": meta}), 200


@puestos_bp.get("/<int:puesto_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def get_puesto(puesto_id: int):
    puesto = puesto_service.get_by_id(puesto_id)
    if puesto is None:
        return jsonify({"error": "Puesto no encontrado."}), 404
    return jsonify({"data": _serialize_puesto(puesto)}), 200


@puestos_bp.put("/<int:puesto_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def update_puesto(puesto_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        puesto = puesto_service.update(puesto_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    except CrudConflictError as error:
        return jsonify({"error": str(error)}), 409
    if puesto is None:
        return jsonify({"error": "Puesto no encontrado."}), 404
    return jsonify({"data": _serialize_puesto(puesto)}), 200


@puestos_bp.patch("/<int:puesto_id>/estado")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def change_puesto_status(puesto_id: int):
    payload = _payload()
    if payload is None:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400
    try:
        puesto = puesto_service.change_status(puesto_id, payload)
    except CrudValidationError as error:
        return jsonify({"error": str(error), "detalles": error.errors}), 400
    if puesto is None:
        return jsonify({"error": "Puesto no encontrado."}), 404
    return jsonify({"data": _serialize_puesto(puesto)}), 200
