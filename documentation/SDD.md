# Especificación del Diseño de Software (SDD)

## 1. Introducción

Pacific Control es un sistema para la gestión de asistencias, turnos y novedades operativas del personal de seguridad. El proyecto comprende un backend Flask, una base de datos PostgreSQL y una aplicación móvil Flutter lista para ejecutarse en emulador Android.

Este documento describe la arquitectura implementada y el estado actual del sistema.

---

## 2. Propósito

Proporcionar una plataforma para registrar y administrar el personal operativo, los turnos asignados, los registros de asistencia y las novedades reportadas, con soporte para el flujo operativo real de identificación de guardias desde dispositivos físicos asignados a puestos/edificios.

---

## 3. Alcance

El sistema está completamente implementado y demostrable de extremo a extremo:

- Backend REST funcional con autenticación JWT y autorización por roles.
- CRUD completo de empleados, puestos, dispositivos, turnos, asistencias y novedades.
- Flujo operativo de identificación de guardia: dispositivo → puesto → guardias disponibles → identificación → asistencia/novedad.
- Aplicación Flutter con Riverpod, go_router, navegación protegida y AuthenticatedApiClient.
- Redis como caché y almacenamiento temporal de sesión operativa.
- Celery para procesamiento asíncrono de novedades.
- Seed idempotente con datos operativos reales de 4 edificios.

---

## 4. Arquitectura General

### Backend (Flask)

```
Routes (HTTP only)
  └── Services (business rules)
       └── Repositories (data access)
            └── Models (SQLAlchemy ORM)
```

**Extensiones registradas:**
- `SQLAlchemy` — ORM PostgreSQL
- `Flask-Migrate / Alembic` — migraciones
- `RedisCache` — caché y almacenamiento temporal
- `JWTManager` — autenticación Bearer token
- `Celery` — tareas asíncronas (broker: Redis)

**Application Factory** (`create_app`): carga configuración desde `.env`, inicializa extensiones, registra 9 blueprints.

### Mobile (Flutter)

```
go_router (navegación declarativa)
  └── Screens (ConsumerWidget)
       └── Providers/Controllers (Riverpod)
            └── Services (HTTP via AuthenticatedApiClient)
```

**Providers de estado:**
- `authControllerProvider` — estado global de autenticación
- `authenticatedApiClientProvider` — cliente HTTP compartido
- Providers por feature: puestos, dispositivos, turnos, asistencias, novedades, empleados, operacion

---

## 5. Autenticación y Autorización

### JWT (Backend)

- **Login:** `POST /auth/login` → `{correo, password}` → `{access_token, empleado}`
- **Token:** HS256, expira en 15 min, claims: `{sub: id_empleado, cargo, correo}`
- **Guard:** `active_employee_required` — verifica JWT + estado activo del empleado en BD en cada request
- **Roles:** `cargo_required(*roles)` — verifica cargo del empleado

### Matriz de permisos

| Endpoint | ADMINISTRADOR | SUPERVISOR | GUARDIA |
|---|---|---|---|
| POST /empleados | ✅ | ❌ | ❌ |
| GET /empleados | ✅ | ✅ | ❌ |
| PUT /empleados/:id | ✅ | ❌ | ❌ |
| PATCH /empleados/:id/estado | ✅ | ❌ | ❌ |
| POST/PUT /puestos | ✅ | ✅ | ❌ |
| GET /puestos | ✅ | ✅ | ✅ |
| POST/PUT /dispositivos | ✅ | ✅ | ❌ |
| GET /dispositivos | ✅ | ✅ | ✅ |
| POST/PUT /turnos | ✅ | ✅ | ❌ |
| GET /turnos | ✅ | ✅ | ✅ |
| POST /asistencias | ✅ | ✅ | ✅ |
| GET /asistencias | ✅ | ✅ | ✅ |
| PUT /asistencias/:id | ✅ | ✅ | ❌ |
| POST /novedades | ✅ | ✅ | ✅ |
| GET /novedades | ✅ | ✅ | ✅ |
| PUT /novedades/:id | ✅ | ✅ | ❌ |
| GET/POST/DELETE /operacion/* | ✅ (sin JWT) | ✅ (sin JWT) | ✅ (sin JWT) |

### Sesión operativa — capa separada del JWT administrativo

Los endpoints `/operacion/*` son **intencionalmente públicos** (no requieren JWT). Representan la capa física del dispositivo instalado en el puesto/edificio. La autenticación aquí es implícita a través del código del dispositivo asociado al puesto, no mediante credenciales administrativas.

**Garantías de seguridad del flujo operativo:**
- **No otorga** permisos administrativos bajo ninguna circunstancia.
- **No expone** tokens JWT ni credenciales de ningún tipo.
- **No permite** crear, modificar ni eliminar empleados, puestos, dispositivos, turnos u otros recursos administrativos.
- **Valida** que el empleado identificado esté activo y tenga un turno activo (FIJO o SACA_FRANCO) en el puesto del dispositivo. Un empleado no asignado recibe 404.
- El estado de la sesión se almacena en Redis con TTL de 12 horas. Sin Redis, opera sin estado (fallback silencioso).
- La identificación operativa **no sustituye** el login administrativo — son mecanismos completamente independientes.

### Mobile

- `AuthController` gestiona el estado de autenticación (restoring / unauthenticated / authenticated)
- `AuthService` persiste el token en `FlutterSecureStorage`
- go_router protege todas las rutas: no autenticado → `/login`
- `AuthenticatedApiClient` inyecta `Authorization: Bearer <token>` en cada request y hace logout automático en 401

---

## 6. Flujo Operativo del Guardia

### Modelo de datos

```
Dispositivo (codigo_dispositivo)
  └── Puesto/Edificio (a través de id_puesto)
       └── Turnos activos (Turno.id_puesto == puesto.id_puesto AND estado == "activo")
            └── Empleados con tipo_asignacion: FIJO | SACA_FRANCO
```

**Reglas clave:**
- El dispositivo pertenece al puesto, no al guardia.
- El tipo de asignación (FIJO/SACA_FRANCO) es una propiedad del Turno, no del Empleado.
- Un empleado puede ser FIJO en un puesto y SACA_FRANCO en otros.
- Un empleado puede ser SACA_FRANCO en múltiples puestos.

### Flujo visual en la app

```
Home → [Operación de dispositivo]
  └── /operacion            → Lista dispositivos activos
  └── /operacion/:id        → Info del dispositivo + puesto + botón "Seleccionar guardia"
  └── /operacion/:id/guardias → Lista FIJO primero, luego SACA_FRANCO + confirmación
  └── /operacion/:id/trabajo  → Guardia identificado + [Registrar asistencia] [Reportar novedad] [Cambiar guardia]
```

### Endpoints operativos

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/operacion/dispositivos/<id>` | Info dispositivo + puesto |
| GET | `/operacion/dispositivos/codigo/<codigo>` | Buscar por código (ej: BAVIERA-01) |
| GET | `/operacion/dispositivos/<id>/guardias` | Guardias activos del puesto |
| GET | `/operacion/dispositivos/<id>/sesion` | Sesión operativa actual |
| POST | `/operacion/dispositivos/<id>/sesion/identificar` | Identificar guardia `{id_empleado}` |
| DELETE | `/operacion/dispositivos/<id>/sesion` | Limpiar identificación |

---

## 7. Modelo de Datos

### Migraciones (cadena Alembic)

1. `82f1e6f726bd` — modelo inicial: 6 tablas base
2. `f11e05b3b0f5` — agrega `password_hash` a `empleados`
3. `a1b2c3d4e5f6` — agrega `tipo_turno` y `tipo_asignacion` a `turnos`

### Tablas principales

| Tabla | Campos clave |
|---|---|
| `empleados` | id, cedula, nombres, apellidos, correo, password_hash, telefono, cargo, estado |
| `puestos` | id, nombre_puesto, direccion, estado |
| `dispositivos` | id, codigo_dispositivo, modelo, estado, id_puesto |
| `turnos` | id, fecha, hora_inicio, hora_fin, estado, tipo_turno, tipo_asignacion, id_empleado, id_puesto |
| `asistencias` | id, fecha_hora, latitud, longitud, foto, observacion, estado, id_empleado, id_turno, id_dispositivo |
| `novedades` | id, tipo, descripcion, fecha_hora, estado, id_empleado, id_turno |

### Valores permitidos

- `tipo_turno`: `24 HORAS`, `12 HORAS`, `MIXTO`
- `tipo_asignacion`: `FIJO`, `SACA_FRANCO`
- `cargo`: `ADMINISTRADOR`, `SUPERVISOR`, `GUARDIA`
- `puesto.estado`: `activo`, `inactivo`
- `turno.estado`: `activo`, `inactivo`

---

## 8. Datos Operativos Oficiales

El seed (`seed_operational.py`) es idempotente y crea:

| Edificio | Dispositivo | Tipo turno | Guardias fijos | Saca francos |
|----------|-------------|------------|----------------|--------------|
| ED. BAVIERA | BAVIERA-01 | 24 HORAS | TIPANTUÑA TACO DIEGO, CACHIHUANGO CEPEDA HUMBERTO | BERNARDO CAMPO MARIO, BETANCOURTH TITUAÑA BYRON |
| ED. CENTURY PLAZA I | CENTURY-01 | 24 HORAS | CAIZAPANTA ITURRALDE VINICIO, VELEZ QUIÑONEZ LUIS | BERNARDO CAMPO MARIO, BETANCOURTH TITUAÑA BYRON |
| ED. GRAND VICTORIA | GRAND-VICTORIA-01 | 12 HORAS | MENDEZ AGUAS FRANKLIN, CEVALLOS SANCHEZ LENIN | PANGAY QUEVEDO STALIN |
| ED. VERTICE | VERTICE-01 | MIXTO | DELGADO TITUAÑA ANDERSON | BERNARDO CAMPO MARIO, BETANCOURTH TITUAÑA BYRON |

**Nota sobre MIXTO:** Vértice opera 12 horas de lunes a viernes y 24 horas sábado/domingo. Los horarios exactos no están definidos en el modelo actual.

### Usuarios de demostración

| Correo | Contraseña | Cargo | Estado |
|--------|------------|-------|--------|
| admin@pacific.test | Admin123! | ADMINISTRADOR | activo |
| supervisor@pacific.test | Supervisor123! | SUPERVISOR | activo |
| guardia@pacific.test | Guardia123! | GUARDIA | activo |
| guardia.demo@pacific.test | Guardia123! | GUARDIA | activo |
| inactivo@pacific.test | Inactivo123! | GUARDIA | **inactivo** |

---

## 9. Optimización

### Redis (cache-aside)

Todos los servicios CRUD aplican el patrón cache-aside:
- **Hit:** retorna el valor cacheado, deserializa el modelo sin tocar la BD.
- **Miss:** consulta la BD, cachea el resultado.
- **Invalidación:** después de create/update/change_status, se eliminan las keys del item y de la lista.

**Claves de caché:** `pacific-control:{resource}:{id}` y `pacific-control:{resource}:all`

**Sesión operativa:** `pacific-control:operacion:sesion:{device_id}` — TTL 12 horas.

### Celery

Las novedades disparan `process_novedad.delay(id)` después de crearse. El task actual registra el evento (stub para procesamiento futuro como alertas o notificaciones).

### Prevención de N+1

Los endpoints de guardias (`/operacion/dispositivos/<id>/guardias`) consultan turnos y empleados en dos queries controladas (no por relación lazy). Las listas CRUD usan `.scalars().all()` en una sola query.

### PgBouncer

El backend es compatible con PgBouncer como capa de connection pooling entre la app y PostgreSQL. La configuración de PgBouncer es una decisión de infraestructura (no incluida en este repositorio). Se recomienda el modo `transaction` para cargas altas.

---

## 10. Pantallas Flutter

| Ruta | Pantalla | Roles |
|------|----------|-------|
| `/login` | LoginPage | Público |
| `/home` | HomePage | Todos |
| `/empleados` | EmpleadosPage | ADMINISTRADOR |
| `/puestos` | PuestosPage | Todos (gestión: ADMIN/SUP) |
| `/dispositivos` | DispositivosPage | Todos (gestión: ADMIN/SUP) |
| `/turnos` | TurnosPage | Todos (gestión: ADMIN/SUP) |
| `/asistencias` | AsistenciasPage | Todos |
| `/novedades` | NovedadesPage | Todos |
| `/operacion` | DispositivoSeleccionPage | Todos |
| `/operacion/:id` | DispositivoInfoPage | Todos |
| `/operacion/:id/guardias` | GuardiaListaPage | Todos |
| `/operacion/:id/trabajo` | GuardiaTrabajoPage | Todos |

---

## 11. Seguridad

- Los tokens JWT se generan con HS256 y expiran a los 15 min.
- La clave secreta requiere mínimo 32 bytes; si no está configurada se genera aleatoriamente.
- Cada request a rutas protegidas verifica que el empleado existe y está activo en la BD (previene tokens stale).
- El backend valida todos los payloads (tipos, longitudes, campos obligatorios, referencias FK).
- La sesión operativa NO es un mecanismo de bypass de autorización.
- Los secretos (JWT key, DB password, etc.) se inyectan por variables de entorno, nunca en el código.
- Flutter no almacena secretos en código: usa `--dart-define=API_BASE_URL=...` en compilación.
- El token se almacena en `FlutterSecureStorage` (Keychain/Keystore según plataforma).

---

## 12. Pruebas

### Backend (pytest)

Se ejecutan 76 tests en 9 archivos:

| Archivo | Tests | Observación |
|---------|-------|-------------|
| test_auth_security.py | Login, JWT inválido/expirado, empleado inactivo | — |
| test_role_security.py | Matriz de permisos, seed idempotente, roles | — |
| test_puesto_crud.py | CRUD completo de puestos | — |
| test_dispositivo_crud.py | CRUD completo de dispositivos | — |
| test_turno_crud.py | CRUD completo de turnos + validación de estado | — |
| test_asistencia_crud.py | CRUD completo de asistencias | — |
| test_novedad_crud.py | CRUD completo de novedades | — |
| test_operational_seed.py | Seed idempotente con datos oficiales | — |
| test_operacion_flow.py | Flujo operativo sin JWT: sesión, guardias, identificación, validación tipo_turno/tipo_asignacion, employee not assigned, inactive, SACA_FRANCO, aislamiento de admin, seed demo | 3 clases de test |

**Resultado:** `76 passed, 6 warnings` — los warnings son SAWarning de SQLAlchemy bajo SQLite en tests (no afectan producción con PostgreSQL).

### Mobile (flutter test)

29 tests en 7 archivos de servicios + widget test. `flutter analyze`: sin issues.

---

## 13. Defectos Preexistentes Conocidos

| Defecto | Impacto | Estado |
|---------|---------|--------|
| Sin refresh token endpoint | El usuario debe re-loguearse cada 15 min | Documentado, no bloquea el flujo |
| `BackendStatusPage` usa `Navigator.push` en lugar de go_router | Inconsistencia menor de navegación | No corregido (no bloquea) |
| Token JWT no se invalida en servidor al hacer logout | El token permanece válido hasta expirar | Documentado, comportamiento típico de JWT stateless |
