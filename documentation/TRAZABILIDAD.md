# Matriz de trazabilidad — Pacific Control

| Requisito | Implementación | Componentes | Endpoint | Prueba/evidencia |
|---|---|---|---|---|
| Backend por capas | Routes → Services → Repositories → Models | `backend/app` | Todos | CRUD tests |
| Base normalizada | 6 modelos y 5 migraciones | `models/`, `migrations/` | CRUD | Tests por recurso |
| JWT y roles | Empleado activo + cargo | `auth/authorization.py` | `/auth/login`, rutas admin | `test_auth_security`, `test_role_security` |
| CRUD | Empleados, puestos, dispositivos, turnos, asistencias, novedades | `routes/`, `services/` | `/<recurso>` | 6 suites CRUD |
| Operación | Login, dispositivo, guardia, turno, asistencia/novedad | `operacion_service.py` | `/operacion/*` | `test_operacion_flow`, `test_semana14_operacion` |
| Reportes | Dashboard, personal y resumen mensual | `report_service.py` | `/reportes/*` | `test_administrative_reports` |
| Redis | Cache-aside y sesión operativa | `cache.py`, `cache_service.py` | Transparente | Tests operativos con fakes |
| Celery | Clasificación asíncrona de novedad | `tasks.py`, `novedad_service.py` | Disparo al crear novedad | Tests de creación de novedad |
| N+1/índices | joinedload e índices compuestos | repositories/reportes, migración `b2c3...` | Listados/reportes | Tests de datos enriquecidos |
| Flutter/API | Cliente autenticado y servicios por feature | `mobile/lib/features`, `services/` | API completa | `mobile/test` |
| Login unificado | Selección por presencia de `@` | `login_page.dart` | `/auth/login` o `/operacion/login` | `unified_login_page_test` |
| Geolocalización | Permiso, GPS, timeout y coordenadas obligatorias | `attendance_location_controller.dart` | Asistencia operativa | `attendance_location_controller_test` |
| Cámara | Permiso y foto opcional | `camera_evidence_controller.dart` | Novedad multipart | `camera_evidence_controller_test` |
| Secure storage | JWT y sesión de dispositivo | auth/operación móvil | — | Tests de servicios |
| ASISTENTE PACIFIC | AgentService + tools allowlist + Gemini/OpenAI-compatible backend | `backend/app/agent`, `mobile/lib/features/agent` | `POST /agente/consultar` | `test_agent.py`, `agent_test.dart` |
| Identidad móvil | Nombre e icono institucional | Android manifest/mipmap, iOS plist | — | Build APK y prueba física |
