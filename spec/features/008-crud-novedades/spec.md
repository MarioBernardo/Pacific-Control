# Especificación Técnica - CRUD Novedades

## Descripción

Este feature implementa el módulo encargado de administrar las novedades registradas durante la operación en el sistema Pacific Control.

## Componentes involucrados

- Models
- Repositories
- Services
- Routes
- Schemas

## Funcionalidades

- Registrar una novedad.
- Consultar una novedad por su identificador.
- Listar todas las novedades.
- Actualizar la información de una novedad.
- Cambiar el estado de una novedad.
- Asociar una novedad a un empleado y un turno.

## Contrato real

| Método | Ruta | Roles | Éxito |
|---|---|---|---|
| POST | `/novedades` | ADMINISTRADOR, SUPERVISOR, GUARDIA | `201` |
| GET | `/novedades`, `/novedades/<id>` | Los tres roles | `200` |
| PUT | `/novedades/<id>` | ADMINISTRADOR, SUPERVISOR | `200` |
| PATCH | `/novedades/<id>/estado` | ADMINISTRADOR, SUPERVISOR | `200` |

No existe `DELETE`; el estado permite la baja lógica. El body exige `tipo`,
`descripcion`, `fecha_hora` ISO 8601, `estado`, `id_empleado` e `id_turno`.
Empleado y Turno deben existir. Los errores son `400` para datos inválidos,
`401` para JWT ausente/inválido, `403` para permisos, `404` para recurso
inexistente y `409` para conflictos de persistencia. La creación publica el
procesamiento asíncrono existente mediante Celery; no se añadió un handler
global `500`.

Las lecturas y mutaciones usan `CacheService` y Flutter ofrece listado,
creación, edición, cambio de estado, estados de carga/error/retry/vacío y
selección de Empleado/Turno.

## Reglas de negocio

- Cada novedad debe tener un identificador único.
- El empleado y el turno asociados deben existir antes de registrar la novedad.
- El tipo, descripción y fecha de la novedad deberán registrarse de forma obligatoria.
- Los campos obligatorios deberán validarse antes de guardar la información.
- Las operaciones deberán devolver respuestas en formato JSON.

## Resultado esperado

Backend y Flutter disponen de gestión funcional de novedades, conservando el
procesamiento asíncrono existente.

## Pruebas realizadas

- Backend: CRUD, validaciones, referencias, Celery simulado en la prueba,
  errores y roles.
- Flutter: GET, POST, PUT, PATCH, relaciones y error `409`.
