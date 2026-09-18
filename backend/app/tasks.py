from app.celery_app import celery
from app.services.novedad_service import NovedadService


@celery.task(name="app.tasks.process_novedad")
def process_novedad(novedad_id: int) -> dict:
    service = NovedadService()
    novedad = service.get_by_id(novedad_id)
    if novedad is None:
        return {"status": "not_found", "novedad_id": novedad_id}

    tipo = (novedad.tipo or "").upper()
    prioridad = "alta" if tipo in {"EMERGENCIA", "ROBO", "ACCIDENTE"} else "normal"
    processed_data = {
        "id_novedad": novedad.id_novedad,
        "tipo": novedad.tipo,
        "estado": novedad.estado,
        "prioridad": prioridad,
        "resumen": (novedad.descripcion or "")[:120],
        "processed_message": f"Novedad {novedad.id_novedad} clasificada para seguimiento.",
    }
    return {"status": "processed", "data": processed_data}
