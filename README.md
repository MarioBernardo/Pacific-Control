# PACIFIC CONTROL

Sistema móvil y API para administrar y supervisar la operación de una empresa de seguridad privada: personal, puestos, dispositivos, turnos, asistencias y novedades.

## Problema y alcance

Digitaliza la asignación de guardias, el registro verificable de asistencia, el reporte de incidentes y la consulta administrativa en tiempo real. El dispositivo pertenece al puesto; cada guardia elige una asignación FIJO/SACA_FRANCO y turno de 12/24 HORAS.

## Arquitectura y stack

- Backend: Python, Flask Application Factory, SQLAlchemy, PostgreSQL, Alembic, JWT, Redis y Celery.
- Capas: routes → services → repositories → models.
- Móvil: Flutter, Riverpod, go_router, HTTP y flutter_secure_storage.
- Nativas: geolocator, image_picker y permission_handler.
- IA: ASISTENTE PACIFIC con Gemini API para la demostración y proveedor OpenAI-compatible alternativo, siempre desde backend.

## Funcionalidades

Administración: login JWT, dashboard, CRUD de seis recursos, personal en turno, resumen mensual, coordenadas, evidencia y agente IA.

Operación: login por puesto, sesión persistente, selección/cambio de guardia, asistencia con ubicación obligatoria, novedad con foto opcional y logout del dispositivo.

ASISTENTE PACIFIC permite a ADMINISTRADOR/SUPERVISOR consultar dashboard, personal, asistencias y novedades mediante lenguaje natural. Usa datos reales obtenidos por herramientas allowlist; no genera SQL ni recibe secretos en Flutter.

## Estructura

- `backend/`: API, migraciones, seeds y tests.
- `mobile/`: aplicación Flutter y tests.
- `documentation/`: API, SDD, trazabilidad y guía final.
- `spec/`: especificaciones funcionales originales.

## Configuración y ejecución

1. Copiar `backend/.env.example` a `backend/.env` y sustituir placeholders sin versionar secretos.
2. Preparar PostgreSQL y Redis.
3. En `backend`: instalar `requirements.txt`, ejecutar `flask --app run.py db upgrade`, cargar el seed e iniciar `python run.py`.
4. Iniciar Celery con `celery -A app.celery_app.celery worker --loglevel=info --pool=solo` en Windows.
5. En `mobile`: `flutter pub get` y `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000`.

Para dispositivo físico, sustituir 10.0.2.2 por la IP LAN del equipo. La guía completa está en [documentation/GUIA_EJECUCION_FINAL.md](documentation/GUIA_EJECUCION_FINAL.md).

## IA

Variables backend: `AI_PROVIDER`, `AI_API_KEY`, `AI_MODEL`, `AI_BASE_URL`, `AI_TIMEOUT_SECONDS`. Para Gemini se recomienda `gemini-2.5-flash`, modelo estable apto para texto y con Free Tier según Google al validar esta integración. Los límites y disponibilidad pueden cambiar. Sin clave/modelo, el endpoint responde 503. Las pruebas usan mocks y no consumen créditos.

## Validación

Backend:
```powershell
cd backend
..\venv\Scripts\python.exe -B -m unittest discover -s tests -v
..\venv\Scripts\python.exe -B -m pip check
```

Flutter:
```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

El APK debug queda en `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

Validación técnica actual: 111 pruebas backend, 73 pruebas Flutter, análisis estático sin incidencias y APK debug compilado correctamente.

## Documentación

- [Contrato API](documentation/api.md)
- [Diseño del sistema](documentation/SDD.md)
- [Trazabilidad](documentation/TRAZABILIDAD.md)
- [Guía final](documentation/GUIA_EJECUCION_FINAL.md)
- [Funciones nativas Semana 14](documentation/SEMANA_14_FUNCIONES_NATIVAS.md)

## Autor

Mario David Bernardo Campo — Universidad Estatal Amazónica, Tecnologías de la Información.
