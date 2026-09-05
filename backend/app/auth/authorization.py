"""Reusable authentication and authorization guards for API endpoints."""

from collections.abc import Callable
from functools import wraps
from typing import ParamSpec, TypeVar

from flask import jsonify
from flask_jwt_extended import get_jwt, get_jwt_identity, jwt_required

from app.repositories.empleado_repository import EmpleadoRepository


P = ParamSpec("P")
R = TypeVar("R")


def active_employee_required(view: Callable[P, R]) -> Callable[P, R]:
    """Require a valid JWT whose employee still exists and is active."""

    @wraps(view)
    @jwt_required()
    def wrapped(*args: P.args, **kwargs: P.kwargs):
        try:
            empleado_id = int(get_jwt_identity())
        except (TypeError, ValueError):
            return _forbidden_response()

        empleado = EmpleadoRepository().get_by_id(empleado_id)
        if empleado is None or not empleado.estado:
            return _forbidden_response()
        return view(*args, **kwargs)

    return wrapped


def cargo_required(*allowed_cargos: str):
    """Build a cargo guard when a documented permission matrix is available."""

    allowed = frozenset(cargo.strip() for cargo in allowed_cargos if cargo.strip())
    if not allowed:
        raise ValueError("Debe indicar al menos un cargo permitido.")

    def decorator(view: Callable[P, R]) -> Callable[P, R]:
        @wraps(view)
        @active_employee_required
        def wrapped(*args: P.args, **kwargs: P.kwargs):
            if get_jwt().get("cargo") not in allowed:
                return _forbidden_response()
            return view(*args, **kwargs)

        return wrapped

    return decorator


def register_jwt_error_handlers(jwt) -> None:
    """Register the JSON error contract for rejected access tokens."""

    @jwt.unauthorized_loader
    def missing_token(_reason: str):
        return _unauthorized_response()

    @jwt.invalid_token_loader
    def invalid_token(_reason: str):
        return _unauthorized_response()

    @jwt.expired_token_loader
    def expired_token(_jwt_header: dict, _jwt_payload: dict):
        return _unauthorized_response()


def _unauthorized_response():
    return jsonify({"error": "Token de acceso no válido o no proporcionado."}), 401


def _forbidden_response():
    return jsonify({"error": "No tiene permiso para acceder a este recurso."}), 403
