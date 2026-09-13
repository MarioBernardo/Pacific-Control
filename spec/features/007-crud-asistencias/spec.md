# Especificación Técnica - CRUD Asistencias

## Descripción

Este feature implementa el módulo encargado de administrar los registros de asistencia del personal en el sistema Pacific Control.

## Componentes involucrados

- Models
- Repositories
- Services
- Routes
- Schemas

## Funcionalidades

- Registrar una asistencia.
- Consultar una asistencia por su identificador.
- Listar todas las asistencias.
- Actualizar la información de una asistencia.
- Cambiar el estado de una asistencia.
- Asociar una asistencia a un empleado, turno y dispositivo.

## Contrato real

| Método | Ruta | Roles | Éxito |
|---|---|---|---|
| POST | `/asistencias` | ADMINISTRADOR, SUPERVISOR, GUARDIA | `201` |
| GET | `/asistencias`, `/asistencias/<id>` | Los tres roles | `200` |
| PUT | `/asistencias/<id>` | ADMINISTRADOR, SUPERVISOR | `200` |
| PATCH | `/asistencias/<id>/estado` | ADMINISTRADOR, SUPERVISOR | `200` |

No existe `DELETE`; el estado permite la baja lógica. El body de creación usa
`fecha_hora` ISO 8601, `latitud`, `longitud`, `estado`, `id_empleado`,
`id_turno`, `id_dispositivo` y los opcionales `foto` y `observacion`.

Las coordenadas se validan en los rangos geográficos, los IDs deben ser enteros
positivos y las tres referencias deben existir. Los errores son `400` para datos
inválidos, `401` para JWT ausente/inválido, `403` para permisos, `404` para
recurso inexistente y `409` para conflictos de persistencia. No se añade un
handler global `500` nuevo.

Las lecturas y mutaciones utilizan `CacheService` e invalidan el registro y la
colección. Flutter incluye listado, creación, edición, cambio de estado,
selección de Empleado/Turno/Dispositivo, loading, retry, vacío y errores HTTP.

## Reglas de negocio

- Cada asistencia debe tener un identificador único.
- El empleado, turno y dispositivo asociados deben existir antes de registrar la asistencia.
- La fecha, hora y ubicación deberán registrarse de forma obligatoria.
- Los campos obligatorios deberán validarse antes de guardar la información.
- Las operaciones deberán devolver respuestas en formato JSON.

## Resultado esperado

Backend y Flutter disponen de gestión funcional de asistencias, respetando las
relaciones existentes con Empleado, Turno y Dispositivo.

## Pruebas realizadas

- Backend: CRUD, validaciones, referencias, errores y roles.
- Flutter: GET, POST, PUT, PATCH, relaciones y error `403`.
