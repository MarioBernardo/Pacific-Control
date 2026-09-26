# Prototipo 15 - pruebas funcionales

## P15-01 - Guardias validos segun puesto

- Objetivo: comprobar que el dispositivo solo recibe guardias con turno activo de hoy en su puesto.
- Nivel: integracion backend/API.
- Riesgo: identificar en un puesto a personal asignado a otro.
- Resultado esperado: HTTP 200 y lista limitada al puesto, con turnos disponibles 12/24.
- Archivo de prueba: `backend/tests/test_prototipo_15.py::test_p15_01_guardias_validos_segun_puesto`.

## P15-02 - Seleccion y propagacion del turno 12/24

- Objetivo: comprobar que la seleccion representa el tipo de turno y conserva el `id_turno` correcto, sin restriccion por hora.
- Nivel: integracion backend/API y widget Flutter.
- Riesgo: registrar operaciones contra un turno distinto del elegido.
- Resultado esperado: tanto 12 HORAS como 24 HORAS se identifican y se propagan a la sesion.
- Archivos de prueba: `backend/tests/test_prototipo_15.py::test_p15_02_seleccion_y_propagacion_turno_12_24` y `mobile/test/features/operacion/operational_navigation_test.dart`.

## P15-03 - Asistencia con ubicacion

- Objetivo: validar coordenadas, asociacion al dispositivo/guardia/turno y persistencia.
- Nivel: integracion backend/API.
- Riesgo: perder la ubicacion o asociar la marcacion a otro turno.
- Resultado esperado: HTTP 201 y un registro con coordenadas, dispositivo y turno seleccionados.
- Archivo de prueba: `backend/tests/test_prototipo_15.py::test_p15_03_asistencia_ubicacion_payload_y_persistencia`.

## P15-04 - Novedad con evidencia

- Objetivo: validar multipart, nombre seguro, archivo persistido y registro asociado al turno y dispositivo.
- Nivel: integracion backend/API y servicio Flutter.
- Riesgo: traversal de ruta, perdida de evidencia o asociacion incorrecta.
- Resultado esperado: HTTP 201, referencia bajo `uploads/novedades/`, archivo existente y asociacion correcta.
- Archivos de prueba: `backend/tests/test_prototipo_15.py::test_p15_04_novedad_multipart_archivo_seguro_y_asociado` y `mobile/test/features/operacion/operacion_incident_service_test.dart`.

## P15-05 - Offline e idempotencia

- Objetivo: guardar antes del HTTP, conservar el mismo `operation_id`, reintentar y evitar duplicados.
- Nivel: persistencia local Flutter e integracion backend/API.
- Riesgo: perder una operacion offline o duplicarla tras una respuesta ambigua.
- Resultado esperado: `PENDIENTE -> ENVIANDO -> SINCRONIZADO` y exactamente un registro backend para el UUID.
- Archivos de prueba: `mobile/test/features/operacion/offline_sync_test.dart::P15-05 offline conserva UUID y sincroniza una sola operacion` y `backend/tests/test_prototipo_15.py::test_p15_05_reintento_idempotente_crea_un_registro`.

## Ejecucion fisica

1. Iniciar PostgreSQL y Redis.
2. En `backend`, ejecutar `..\venv\Scripts\flask.exe --app run.py db upgrade`.
3. Generar asignaciones vigentes con `..\venv\Scripts\python.exe -m app.seed_operational`.
4. Iniciar el backend.
5. En otra consola de Windows, iniciar Celery con:

   `..\venv\Scripts\celery.exe -A app.celery_app.celery worker --loglevel=info --pool=solo`

6. Ejecutar P15-01 a P15-05 en un dispositivo, incluyendo modo avion para P15-05.
