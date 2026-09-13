# Especificación Técnica - CRUD Turnos

## Descripción

Este feature implementa el módulo encargado de administrar la información de los turnos registrados en el sistema Pacific Control.

## Componentes involucrados

- Models
- Repositories
- Services
- Routes
- Schemas

## Funcionalidades

- Registrar un turno.
- Consultar un turno por su identificador.
- Listar todos los turnos.
- Actualizar la información de un turno.
- Cambiar el estado de un turno.
- Asociar un turno a un empleado y un puesto.

## Modelo y relaciones

El modelo contiene `id_turno`, `fecha`, `hora_inicio`, `hora_fin`, `estado`,
`id_empleado` e `id_puesto`. `id_empleado` referencia a un Empleado y
`id_puesto` referencia a un Puesto; ambos son obligatorios. Asistencias y
Novedades también pueden referenciar un turno.

Las fechas y horas se transportan como texto ISO 8601: `YYYY-MM-DD` para la
fecha y `HH:MM:SS` para las horas.

## Endpoints reales

Todos los endpoints requieren un Bearer JWT de un empleado activo.

| Método | Ruta | Permisos | Respuesta exitosa |
|---|---|---|---|
| POST | `/turnos` | ADMINISTRADOR, SUPERVISOR | `201` con `data` |
| GET | `/turnos` | ADMINISTRADOR, SUPERVISOR, GUARDIA | `200` con lista `data` |
| GET | `/turnos/<turno_id>` | ADMINISTRADOR, SUPERVISOR, GUARDIA | `200` con `data` |
| PUT | `/turnos/<turno_id>` | ADMINISTRADOR, SUPERVISOR | `200` con `data` |
| PATCH | `/turnos/<turno_id>/estado` | ADMINISTRADOR, SUPERVISOR | `200` con `data` |

No existe `DELETE`; `PATCH /estado` realiza la baja lógica.

### Body de creación

```json
{
	"fecha": "2026-09-13",
	"hora_inicio": "08:00:00",
	"hora_fin": "16:00:00",
	"estado": "activo",
	"id_empleado": 4,
	"id_puesto": 3
}
```

`PUT` acepta una actualización parcial con campos permitidos. `PATCH` acepta
únicamente `{ "estado": "inactivo" }`.

## Reglas de negocio

- Cada turno debe tener un identificador único.
- El empleado y el puesto asociados deben existir antes de registrar el turno.
- La fecha y el horario del turno deberán registrarse de forma obligatoria.
- Los campos obligatorios deberán validarse antes de guardar la información.
- Las operaciones deberán devolver respuestas en formato JSON.

## Validaciones, errores y limitaciones reales

- Campos obligatorios, campos desconocidos, fecha/hora no ISO, strings vacíos e
	IDs no positivos producen `400` con `error` y `detalles`.
- Empleado o Puesto inexistente al crear o actualizar produce `400`.
- Token ausente, inválido o expirado produce `401`.
- Guardia puede consultar, pero no crear, actualizar ni cambiar estado; un cargo
	desconocido produce `403`.
- Turno inexistente produce `404`.
- `409` queda reservado para conflictos de integridad capturados al guardar;
	el modelo actual no define una regla de unicidad de negocio para turnos.
- No existe un handler global `500` específico de este módulo; los errores
	inesperados conservan el manejo superior existente de Flask.

El contrato actual no define catálogo de estados, coherencia obligatoria entre
`hora_inicio` y `hora_fin`, solapamiento de turnos, ni exigencia de que Empleado
o Puesto estén activos. Estas reglas no se inventan en este módulo y permanecen
como limitaciones documentadas.

## Flujo y caché

El flujo es `turnos_bp -> cargo_required -> TurnoService -> TurnoRepository ->
SQLAlchemy`. Las lecturas usan caché individual y de colección; las mutaciones
invalidan ambas entradas mediante `CacheService`.

## Resultado esperado

El backend y Flutter disponen de un módulo demostrable para listar, crear,
editar y cambiar el estado de turnos. Flutter permite seleccionar Empleado y
Puesto existentes, serializa fecha/hora con el formato real de la API y muestra
estados de carga, error con reintento, lista vacía y éxito.

## Pruebas realizadas

- Backend: 6 pruebas CRUD, validaciones, referencias, `404`, payload PATCH y
	permisos.
- Flutter: 3 pruebas del servicio para GET, POST, PUT, PATCH, relaciones,
	fecha/hora y errores HTTP.
- Flutter: `flutter analyze` sin issues.
