from app.celery_app import celery
from app.services.novedad_service import NovedadService


@celery.task(name="app.tasks.process_novedad")
def process_novedad(novedad_id: int) -> dict:
    service = NovedadService()
    novedad = service.get_by_id(novedad_id)
    if novedad is None:
        return {"status": "not_found", "novedad_id": novedad_id}

    # Simulate asynchronous processing logic for the novedad.
    processed_data = {
        "id_novedad": novedad.id_novedad,
        "tipo": novedad.tipo,
        "estado": novedad.estado,
        "processed_message": f"Novedad {novedad.id_novedad} procesada asincrónicamente.",
    }
    return {"status": "processed", "data": processed_data}
