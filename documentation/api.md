# API REST — Pacific Control

Base local: `http://localhost:5000`. Todas las respuestas son JSON salvo la descarga de evidencia. Los endpoints administrativos usan `Authorization: Bearer <JWT>`; los operativos usan `X-Device-Session`.

## Autenticación

| Método | Ruta | Auth | Request | Resultado |
|---|---|---|---|---|
| POST | `/auth/login` | Pública | `{correo,password}` | JWT y empleado; 400/401 |
| POST | `/operacion/login` | Pública | `{usuario,password}` | Sesión opaca y dispositivo; 400/401/503 |
| POST | `/operacion/dispositivos/<id>/logout` | Sesión dispositivo | — | Invalida sesión; 200/401/503 |

El login Flutter decide por el identificador: con `@` usa autenticación administrativa; sin `@`, autenticación operativa.

## CRUD administrativo

Los listados soportan paginación y filtros permitidos por recurso; responden con `data` y `meta`.

| Recurso | Rutas | Operaciones | Roles |
|---|---|---|---|
| Empleados | `/empleados`, `/empleados/<id>`, `/empleados/<id>/estado` | POST, GET, PUT, PATCH | ADMIN; lectura SUPERVISOR |
| Puestos | `/puestos`, `/puestos/<id>`, `/puestos/<id>/estado` | POST, GET, PUT, PATCH | ADMIN/SUPERVISOR; lectura GUARDIA |
| Dispositivos | `/dispositivos`, `/dispositivos/<id>`, `/dispositivos/<id>/estado` | POST, GET, PUT, PATCH | ADMIN/SUPERVISOR; lectura GUARDIA |
| Turnos | `/turnos`, `/turnos/<id>`, `/turnos/<id>/estado` | POST, GET, PUT, PATCH | ADMIN/SUPERVISOR; lectura GUARDIA |
| Asistencias | `/asistencias`, `/asistencias/<id>`, `/asistencias/<id>/estado` | POST, GET, PUT, PATCH | JWT según matriz |
| Novedades | `/novedades`, `/novedades/<id>`, `/novedades/<id>/estado` | POST, GET, PUT, PATCH | JWT según matriz |

Complementos: `GET /turnos/meta/opciones` y `GET /novedades/<id>/evidencia` (ADMIN/SUPERVISOR). Errores habituales: 400 validación, 401 token, 403 rol, 404 recurso, 409 conflicto y 500.

## Operación de dispositivo

| Método | Ruta | Propósito |
|---|---|---|
| GET | `/operacion/dispositivos/codigo/<codigo>` | Aprovisionamiento compatible |
| GET | `/operacion/dispositivos/<id>` | Dispositivo y puesto |
| GET | `/operacion/dispositivos/<id>/guardias` | Guardias y turnos disponibles |
| GET | `/operacion/dispositivos/<id>/sesion` | Guardia identificado |
| POST | `/operacion/dispositivos/<id>/sesion/identificar` | `{id_empleado,tipo_turno}` |
| DELETE | `/operacion/dispositivos/<id>/sesion` | Cambiar guardia |
| POST | `/operacion/dispositivos/<id>/asistencias` | `{latitud,longitud,observacion?}` |
| POST | `/operacion/dispositivos/<id>/novedades` | Novedad JSON |
| POST | `/operacion/dispositivos/<id>/novedades-con-foto` | Multipart `tipo`, `descripcion`, `foto?` |

La asistencia exige coordenadas válidas. La evidencia admite JPEG/PNG hasta el límite configurado. Redis es obligatorio por defecto para sesiones operativas.

## Reportes

| Método | Ruta | Roles | Resultado |
|---|---|---|---|
| GET | `/reportes/dashboard` | ADMIN/SUPERVISOR | Indicadores y guardias en turno |
| GET | `/reportes/personal-en-turno` | ADMIN/SUPERVISOR | Personal cubriendo puestos |
| GET | `/reportes/guardias/<id>/resumen-mensual?mes=&anio=` | ADMIN/SUPERVISOR | Asistencias, horas, puestos y novedades |

## ASISTENTE PACIFIC

`POST /agente/consultar`, solo ADMINISTRADOR o SUPERVISOR.

Request: `{"pregunta":"¿Cuántos guardias están en turno?"}`

Response 200:
```json
{"data":{"respuesta":"...","datos":{"dashboard":{}},"fuentes_internas":["reportes.dashboard"],"generado_por_ia":true}}
```

Errores: 400 pregunta inválida o mayor a 500 caracteres; 401/403 auth; 502 proveedor falló; 503 proveedor no configurado; 504 timeout. Usa herramientas allowlist, nunca SQL/comandos generados, y la API key permanece en backend. La demostración utiliza Gemini REST `models/<modelo>:generateContent`; el proveedor OpenAI-compatible continúa disponible por configuración.
