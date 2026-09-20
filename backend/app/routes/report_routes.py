from datetime import datetime

from flask import Blueprint, jsonify, request

from app.auth.authorization import cargo_required
from app.services.report_service import ReportService


reportes_bp = Blueprint("reportes", __name__, url_prefix="/reportes")
report_service = ReportService()


@reportes_bp.get("/dashboard")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def dashboard():
    return jsonify({"data": report_service.dashboard()}), 200


@reportes_bp.get("/personal-en-turno")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def personnel_on_shift():
    return jsonify({"data": report_service.personnel_on_shift()}), 200


@reportes_bp.get("/guardias/<int:employee_id>/resumen-mensual")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def monthly_summary(employee_id: int):
    now = datetime.now()
    try:
        month = int(request.args.get("mes", now.month))
        year = int(request.args.get("anio", now.year))
        if month < 1 or month > 12 or year < 2000 or year > 2100:
            raise ValueError
    except ValueError:
        return jsonify({"error": "mes o anio no son válidos."}), 400
    return jsonify({"data": report_service.monthly_summary(employee_id, month, year)}), 200
