from flask import Blueprint, jsonify, request
from app.auth.authorization import cargo_required
from app.models.turno import Turno
from app.services.crud_utils import CrudConflictError, CrudValidationError
from app.services.turno_service import TurnoService, VALID_TIPO_TURNO, VALID_TIPO_ASIGNACION
from app.services.query_service import paginated
from app.services.cache_service import cache_service
from sqlalchemy.orm import joinedload


turnos_bp = Blueprint("turnos", __name__, url_prefix="/turnos")
turno_service = TurnoService()


def _serialize_turno(turno: Turno) -> dict:
    return {
        "id_turno": turno.id_turno,
        "fecha": turno.fecha.isoformat(),
        "hora_inicio": turno.hora_inicio.isoformat() if turno.hora_inicio else None,
        "hora_fin": turno.hora_fin.isoformat() if turno.hora_fin else None,
        "estado": turno.estado,
        "tipo_turno": turno.tipo_turno,
        "tipo_asignacion": turno.tipo_asignacion,
        "id_empleado": turno.id_empleado,
        "id_puesto": turno.id_puesto,
        "empleado": {
            "id_empleado": turno.empleado.id_empleado,
            "nombre_completo": f"{turno.empleado.nombres} {turno.empleado.apellidos}",
        },
        "puesto": {
            "id_puesto": turno.puesto.id_puesto,
            "nombre_puesto": turno.puesto.nombre_puesto,
        },
    }


def _payload():
    return request.get_json(silent=True)


@turnos_bp.post("")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
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
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def list_turnos():
    try: items, meta = paginated(Turno, filters={"estado": Turno.estado, "id_empleado": Turno.id_empleado, "id_puesto": Turno.id_puesto, "fecha": Turno.fecha, "tipo_turno": Turno.tipo_turno, "tipo_asignacion": Turno.tipo_asignacion}, sort_fields={"id_turno": Turno.id_turno, "fecha": Turno.fecha}, options=(joinedload(Turno.empleado), joinedload(Turno.puesto)))
    except CrudValidationError as error: return jsonify({"error": str(error), "detalles": error.errors}), 400
    return jsonify({"data": [_serialize_turno(item) for item in items], "meta": meta}), 200


@turnos_bp.get("/<int:turno_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def get_turno(turno_id: int):
    data = cache_service.get_by_id(
        "turno", turno_id,
        lambda: turno_service.get_by_id(turno_id),
        _serialize_turno,
    )
    if data is None:
        return jsonify({"error": "Turno no encontrado."}), 404
    return jsonify({"data": data}), 200


@turnos_bp.put("/<int:turno_id>")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
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
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
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


@turnos_bp.get("/meta/opciones")
@cargo_required("ADMINISTRADOR", "SUPERVISOR", "GUARDIA")
def turno_options():
    """Return the valid enum values for tipo_turno and tipo_asignacion."""
    return jsonify({
        "data": {
            "tipo_turno": sorted(VALID_TIPO_TURNO),
            "tipo_asignacion": sorted(VALID_TIPO_ASIGNACION),
        }
    }), 200
