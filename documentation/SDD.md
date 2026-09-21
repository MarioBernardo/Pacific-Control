# Especificación del Diseño de Software — Pacific Control

## 1. Alcance

Pacific Control gestiona empleados, puestos, dispositivos, turnos, asistencias y novedades de una empresa de seguridad privada. Incluye administración autenticada, operación por dispositivo, reportes y ASISTENTE PACIFIC.

## 2. Arquitectura

### Backend

Flask Application Factory registra blueprints HTTP. Las rutas delegan reglas a Services, estos usan Repositories y modelos SQLAlchemy sobre PostgreSQL. Alembic mantiene cinco migraciones. JWT protege administración; Redis implementa cache-aside y sesiones operativas; Celery procesa novedades en segundo plano.

### Flutter

Flutter usa Riverpod para estado, go_router para navegación, servicios HTTP tipados y flutter_secure_storage. La pantalla institucional unifica el acceso: identificadores con `@` usan JWT y los demás usan login operativo. Android/iOS muestran `PACIFIC CONTROL`.

## 3. Dominio

- Empleado: identidad, cargo, estado y credencial administrativa.
- Puesto: ubicación operativa.
- Dispositivo: pertenece al puesto, nunca al guardia.
- Turno: empleado + puesto; FIJO/SACA_FRANCO y 12/24 HORAS.
- Asistencia: empleado, turno, dispositivo, fecha y coordenadas obligatorias.
- Novedad: incidente con evidencia JPEG/PNG opcional.

## 4. Seguridad

Las contraseñas y secretos operativos se almacenan con hash. JWT dura 15 minutos y cada petición verifica empleado activo y rol. La sesión operativa usa token opaco en secure storage y Redis; no concede acceso administrativo. Las evidencias tienen firma/tamaño/nombre controlados. `.env` no se versiona.

## 5. Flujos

### Administración
Login JWT → dashboard/CRUD/reportes/agente → API → servicio → repositorio → PostgreSQL → Flutter.

### Operación
Login de puesto → sesión de dispositivo → guardias disponibles → guardia/turno → asistencia con ubicación o novedad con foto opcional. Cambiar guardia limpia la identificación; logout invalida el dispositivo.

### ASISTENTE PACIFIC
Flutter → `POST /agente/consultar` con JWT → AgentService → herramientas de reportes allowlist → proveedor LLM backend → respuesta estructurada. Para la demostración se usa Gemini REST `generateContent`; se conserva el proveedor OpenAI-compatible. La API key nunca llega a Flutter. El modelo no genera SQL ni ejecuta herramientas arbitrarias.

## 6. Funciones nativas

Geolocalización y cámara explican el uso antes del permiso, distinguen denegado/permanente y permiten ajustes. Ubicación usa timeout de 15 segundos y nunca registra asistencia sin coordenadas reales.

## 7. Optimización

- Índices en dispositivo/puesto/estado, turnos, asistencias y novedades.
- joinedload y consultas controladas contra N+1.
- Paginación máxima de 100.
- Cache-aside Redis con invalidación.
- Sesiones operativas Redis con TTL.
- Celery se dispara tras guardar una novedad; clasifica prioridad y resumen. Si el broker cae, la novedad permanece y se registra warning.

## 8. Navegación móvil

Rutas administrativas: `/home`, `/empleados`, `/puestos`, `/dispositivos`, `/turnos`, `/asistencias`, `/novedades`, `/personal-en-turno`, actividad de guardia y `/asistente-pacific`.

Rutas operativas: `/operacion/:deviceId` y `/operacion/:deviceId/guardias`. `/operacion` vuelve al login.

## 9. Configuración

Variables reales y placeholders están en `backend/.env.example`. Flutter recibe `API_BASE_URL` mediante `--dart-define`. PostgreSQL, Redis y Celery se preparan según `GUIA_EJECUCION_FINAL.md`.

## 10. Pruebas

La validación final ejecuta 111 pruebas backend y 73 pruebas Flutter para seguridad, CRUD, reportes, operación, permisos nativos y agente. Veintiuna pruebas cubren específicamente agente/proveedores y el registro canónico de la ruta, incluido Gemini REST. Todas mockean el proveedor: no usan Internet ni créditos. `flutter analyze` finaliza sin incidencias y el APK debug compila correctamente.
