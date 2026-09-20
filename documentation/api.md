# API REST de Pacific Control

## 1. Introducción

La API REST de Pacific Control corresponde al backend implementado con Flask. En el estado actual, expone una única ruta de disponibilidad. Los módulos REST para la administración de empleados, puestos, dispositivos, turnos, asistencias y novedades están documentados como funcionalidades planificadas, pero sus rutas y contratos aún no están implementados.

Este documento diferencia los elementos disponibles en el backend de las operaciones previstas en las especificaciones funcionales.

## 2. Convenciones generales

La ruta implementada está registrada mediante un blueprint de Flask y devuelve una respuesta JSON. No se ha definido un prefijo común de API, versionado de rutas, convención de nombres para recursos ni contratos de solicitud en el código actual.

Las especificaciones de los módulos CRUD establecen que sus operaciones deberán devolver respuestas en formato JSON. La definición de rutas, métodos HTTP, parámetros y cuerpos de solicitud permanece pendiente de implementación.

## 3. Formato JSON

La respuesta de la ruta implementada es un objeto JSON. Flask realiza la serialización de la estructura devuelta por la ruta.

No existe una envoltura general de respuesta implementada para toda la API. Tampoco se han definido formatos comunes para colecciones, paginación, metadatos ni respuestas de error.

| Elemento | Estado actual |
| --- | --- |
| Respuesta de disponibilidad | Objeto JSON implementado. |
| Respuestas de módulos CRUD | Planificadas en formato JSON. |
| Estructura común de respuesta | No definida. |
| Formato de errores | No definido. |

## 4. Códigos HTTP utilizados

El único código HTTP confirmado por la implementación actual es el siguiente:

| Código | Nombre | Uso actual |
| --- | --- | --- |
| `200` | OK | Respuesta satisfactoria de `GET /`. |

No se han implementado ni documentado códigos específicos para creación, validación, recursos inexistentes, conflictos o errores internos en los módulos planificados.

## 5. Endpoint implementado actualmente

| Método | Ruta | Estado | Descripción |
| --- | --- | --- |
| `GET` | `/` | Implementado | Devuelve información básica que identifica el proyecto, informa que el backend está funcionando e incluye una versión. |

La respuesta contiene los campos `project`, `status` y `version`. Esta estructura pertenece únicamente a la ruta de disponibilidad; no constituye un contrato general para los futuros módulos.

## 6. Endpoints planificados

Las funcionalidades 003 a 008 describen módulos CRUD, pero no definen rutas concretas, métodos HTTP ni contratos de solicitud o respuesta. Por este motivo, no se asignan URLs ni verbos que no existan en el proyecto.

| Recurso | Estado | Operaciones planificadas | Rutas y métodos |
| --- | --- | --- | --- |
| Empleados | Planificado | Registrar, consultar por identificador, listar, actualizar y cambiar estado. | Pendientes de definición e implementación. |
| Puestos | Planificado | Registrar, consultar por identificador, listar, actualizar y cambiar estado. | Pendientes de definición e implementación. |
| Dispositivos | Planificado | Registrar, consultar por identificador, listar, actualizar, cambiar estado y asociar a un puesto. | Pendientes de definición e implementación. |
| Turnos | Planificado | Registrar, consultar por identificador, listar, actualizar, cambiar estado y asociar a un empleado y un puesto. | Pendientes de definición e implementación. |
| Asistencias | Planificado | Registrar, consultar por identificador, listar, actualizar, cambiar estado y asociar a un empleado, turno y dispositivo. | Pendientes de definición e implementación. |
| Novedades | Planificado | Registrar, consultar por identificador, listar, actualizar, cambiar estado y asociar a un empleado y un turno. | Pendientes de definición e implementación. |

Las tablas anteriores describen el alcance funcional documentado. No representan endpoints disponibles ni contratos implementados.

## 7. Estructura general de las respuestas

Actualmente no existe una estructura general compartida por toda la API. La única respuesta implementada se organiza como un objeto JSON directo con información de disponibilidad.

| Tipo de respuesta | Estructura actual | Estado |
| --- | --- | --- |
| Disponibilidad | Campos `project`, `status` y `version`. | Implementada para `GET /`. |
| Operación CRUD satisfactoria | Deberá devolverse en JSON según las especificaciones. | Planificada; estructura no definida. |
| Error de API | No definida. | No implementada. |

Hasta que se implementen los módulos CRUD, no existe un contrato uniforme para representar recursos individuales, colecciones o resultados de operaciones.

## 8. Manejo de errores

El backend actual no implementa un mecanismo específico de manejo de errores para la API. La ruta disponible no define validaciones de entrada ni respuestas de error personalizadas.

Las especificaciones CRUD indican que los campos obligatorios deberán validarse antes de guardar información y que no se permitirá registrar información incompleta. Sin embargo, aún no se han definido los códigos HTTP, el formato JSON de los errores, los mensajes ni los controladores necesarios para materializar esas validaciones.

La autenticación JWT no está implementada y, por tanto, no existen respuestas de error de autenticación o autorización en la API actual.
# Contrato actualizado: operación y colecciones

Todas las rutas CRUD administrativas conservan JWT y su matriz de roles. Sus
GET de colección devuelven `data` y `meta` (`page`, `per_page`, `total`,
`pages`), con un máximo de 100 filas. Los filtros dependen del recurso y el
orden sólo admite campos declarados por el endpoint.

| Método | Ruta | Propósito | Autenticación | Resultado principal |
|---|---|---|---|---|
| POST | `/auth/login` | Crear sesión administrativa | Pública | JWT y empleado; 400/401 |
| GET/POST | `/empleados`, `/puestos`, `/dispositivos`, `/turnos`, `/asistencias`, `/novedades` | Consultar/crear | JWT y rol vigente | 200/201/400/401/403 |
| GET/PUT/PATCH | `/<recurso>/<id>` y `/<recurso>/<id>/estado` | Consultar/editar/cambiar estado | JWT y rol vigente | 200/400/401/403/404 |
| GET | `/turnos/meta/opciones` | Catálogos de turno | JWT | 200 |
| GET | `/operacion/dispositivos/codigo/<codigo>` | Resolver código durante aprovisionamiento | Pública | Datos sin secreto; 200/404 |
| GET | `/operacion/dispositivos/<id>` | Validar dispositivo y puesto | `X-Device-Token` | 200/401/404 |
| GET | `/operacion/dispositivos/<id>/guardias` | Asignaciones vigentes del día | `X-Device-Token` | 200/401/404 |
| GET/POST/DELETE | `/operacion/dispositivos/<id>/sesion[/identificar]` | Consultar, identificar o finalizar | `X-Device-Token` | 200/400/401/404/503 |
| POST | `/operacion/dispositivos/<id>/asistencias` | Registrar al guardia de sesión | `X-Device-Token` + sesión Redis | 201/400/401/409 |
| POST | `/operacion/dispositivos/<id>/novedades` | Reportar como guardia de sesión | `X-Device-Token` + sesión Redis | 201/400/401/409 |

La API deriva `id_empleado`, `id_turno` e `id_dispositivo` de la sesión en las
escrituras operativas. Un JSON que no sea objeto devuelve 400. El cliente no
puede usar esos cuerpos para suplantar a otro empleado.
# Seleccion operativa de turno

`GET /operacion/dispositivos/<id>/guardias` devuelve una sola entrada por
empleado e incluye `turnos_disponibles`, con el `id_turno` real de `12 HORAS` y
`24 HORAS`. La identificacion exige
`{"id_empleado": <int>, "tipo_turno": "12 HORAS" | "24 HORAS"}`. El servidor
resuelve el turno correspondiente y no confia en un `id_turno` enviado por el
cliente. La sesion Redis almacena el turno y la modalidad seleccionada.
# Operación Semana 14

- `POST /operacion/login`: `{ "usuario": "baviera", "password": "..." }`; devuelve token opaco y dispositivo/puesto.
- Los endpoints protegidos de operación aceptan `X-Device-Session`; `X-Device-Token` queda como compatibilidad interna.
- `POST /operacion/dispositivos/<id>/logout`: invalida el vínculo y limpia el guardia.
- `POST /operacion/dispositivos/<id>/asistencias`: requiere latitud `[-90,90]` y longitud `[-180,180]`.
- `POST /operacion/dispositivos/<id>/novedades-con-foto`: multipart con `tipo`, `descripcion` y `foto` opcional JPEG/PNG de hasta 5 MB.
