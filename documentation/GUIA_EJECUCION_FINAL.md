# Guía final de ejecución y demostración

## 1. Requisitos

Python 3, PostgreSQL, Redis, Flutter compatible con SDK Android configurado y un dispositivo/emulador. No versionar `.env`, claves, APK ni uploads.

## 2. Backend

1. Crear `backend/.env` desde `.env.example` y sustituir placeholders.
2. Crear la base `pacific_control` en PostgreSQL.
3. Desde `backend`, activar `..\venv\Scripts\activate` e instalar: `pip install -r requirements.txt`.
4. Aplicar migraciones: `flask --app run.py db upgrade`.
5. Cargar datos demostrativos con el mecanismo de seed vigente del proyecto.
6. Iniciar Redis en `REDIS_URL`.
7. Iniciar Flask: `python run.py`.
8. En otra terminal iniciar Celery: `celery -A app.celery_app.celery worker --loglevel=info --pool=solo` (Windows).

Sin Redis, el cache degrada a base de datos, pero la sesión operativa devuelve 503 por seguridad cuando `REQUIRE_REDIS_OPERATIVE_SESSION=true`. Sin Celery, la novedad se guarda y el despacho asíncrono deja un warning.

## 3. Configuración IA

Definir solo en `backend/.env`: `AI_PROVIDER=gemini`, `AI_API_KEY`, `AI_MODEL=gemini-2.5-flash`, `AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta` y timeout. La clave nunca se añade a Flutter. El modelo permanece reemplazable; el Free Tier y sus límites pueden cambiar. Sin clave/modelo, `/agente/consultar` responde 503 de forma controlada. Para volver al proveedor alternativo use `AI_PROVIDER=openai` junto con su base URL, clave y modelo compatibles.

Comprobar la configuración sin revelar valores: `..\venv\Scripts\python.exe -B check_ai_config.py` desde `backend`.

## 4. Flutter

- Emulador Android: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000`.
- Dispositivo físico: obtener la IP LAN del equipo, permitir puerto 5000 en red privada y ejecutar `flutter run --dart-define=API_BASE_URL=http://IP_LAN:5000`.
- El móvil y el equipo deben estar en la misma red. Para ubicación del emulador, configurar una posición en Extended Controls → Location.

## 5. Demostración

1. Login administrativo con una cuenta demo autorizada.
2. Mostrar dashboard, CRUD, personal en turno, resumen mensual, coordenadas y evidencia.
3. Abrir ASISTENTE PACIFIC y ejecutar una pregunta rápida.
4. Cerrar sesión y entrar con un usuario operativo demo.
5. Seleccionar guardia y 12/24 HORAS; registrar asistencia con ubicación real.
6. Crear novedad con y sin foto; cambiar guardia y hacer logout del dispositivo.

## 6. Validación

Backend desde `backend`: `..\venv\Scripts\python.exe -B -m unittest discover -s tests -v` y `..\venv\Scripts\python.exe -B -m pip check`.

Flutter desde `mobile`: `flutter pub get`, `flutter analyze`, `flutter test` y `flutter build apk --debug`. APK esperado: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

## 7. Troubleshooting

- 503 operativo: comprobar Redis y `REDIS_URL`.
- 503 agente: configurar `AI_API_KEY` y `AI_MODEL`.
- 502 agente: verificar red, base URL, modelo y saldo/cuota del proveedor.
- Sin conexión desde dispositivo: revisar IP LAN, firewall y que Flask escuche `0.0.0.0:5000`.
- Sin ubicación: activar GPS/permisos y definir ubicación del emulador; nunca usar coordenadas ficticias.
- Cámara denegada permanentemente: abrir ajustes desde el diálogo de la app.
