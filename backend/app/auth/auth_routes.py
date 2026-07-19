from flask import Blueprint, jsonify, request

from app.auth.auth_service import AuthService, AuthenticationError


auth_bp = Blueprint("auth", __name__, url_prefix="/auth")

auth_service = AuthService()


@auth_bp.post("/login")
def login():
    """Authenticate empleado and return JWT access token."""
    payload = request.get_json(silent=True)
    if not payload:
        return jsonify({"error": "Debe enviar un objeto JSON válido."}), 400

    correo = payload.get("correo")
    password = payload.get("password")

    if not correo or not password:
        return jsonify({"error": "Correo y password son obligatorios."}), 400

    try:
        result = auth_service.login(correo, password)
    except AuthenticationError:
        return jsonify({"error": "Credenciales inválidas."}), 401

    return jsonify({"data": result}), 200
