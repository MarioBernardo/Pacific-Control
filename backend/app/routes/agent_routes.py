from flask import Blueprint, jsonify, request

from app.agent.provider import (
    AgentProviderError,
    AgentProviderNotConfigured,
    AgentProviderTimeout,
)
from app.agent.service import AgentService, AgentValidationError
from app.auth.authorization import cargo_required


agente_bp = Blueprint("agente", __name__, url_prefix="/agente")


@agente_bp.post("/consultar")
@cargo_required("ADMINISTRADOR", "SUPERVISOR")
def consult_agent():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "El cuerpo debe ser un objeto JSON."}), 400
    try:
        result = AgentService().consult(payload.get("pregunta"))
        return jsonify({"data": result}), 200
    except AgentValidationError as error:
        return jsonify({"error": str(error)}), 400
    except AgentProviderNotConfigured as error:
        return jsonify({"error": "El servicio de inteligencia artificial no está configurado."}), 503
    except AgentProviderTimeout:
        return jsonify({"error": "El asistente tardó demasiado en responder. Intente nuevamente."}), 504
    except AgentProviderError:
        return jsonify({"error": "El servicio de inteligencia artificial no está disponible temporalmente."}), 502
