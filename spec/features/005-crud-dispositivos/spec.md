# Especificación Técnica - CRUD Dispositivos

## Descripción

Este feature implementa el módulo encargado de administrar la información de los dispositivos registrados en el sistema Pacific Control.

## Componentes involucrados

- Models
- Repositories
- Services
- Routes
- Schemas

## Funcionalidades

- Registrar un dispositivo.
- Consultar un dispositivo por su identificador.
- Listar todos los dispositivos.
- Actualizar la información de un dispositivo.
- Cambiar el estado de un dispositivo.
- Asociar un dispositivo a un puesto.

## Modelo y relación

El modelo contiene `id_dispositivo`, `codigo_dispositivo`, `modelo`, `estado` e
`id_puesto`. `codigo_dispositivo` es único. `id_puesto` es obligatorio y es una
FK hacia `puestos.id_puesto`; el puesto debe existir antes de crear o cambiar la
asociación. No se requiere que el puesto esté activo y la respuesta no incluye
datos anidados del puesto.

## Endpoints reales

Todos requieren un Bearer JWT de un empleado activo.

| Método | Ruta | Permisos | Respuesta exitosa |
|---|---|---|---|
| POST | `/dispositivos` | ADMINISTRADOR, SUPERVISOR | `201` con `data` |
| GET | `/dispositivos` | ADMINISTRADOR, SUPERVISOR, GUARDIA | `200` con lista `data` |
| GET | `/dispositivos/<id>` | ADMINISTRADOR, SUPERVISOR, GUARDIA | `200` con `data` |
| PUT | `/dispositivos/<id>` | ADMINISTRADOR, SUPERVISOR | `200` con `data` |
| PATCH | `/dispositivos/<id>/estado` | ADMINISTRADOR, SUPERVISOR | `200` con `data` |

No existe `DELETE`; `PATCH /estado` realiza la baja lógica.

### Body

Para `POST`:

```json
{
	"codigo_dispositivo": "DISP-001",
	"modelo": "Android",
	"estado": "activo",
	"id_puesto": 3
}
```

`PUT` acepta uno o más campos permitidos. `PATCH` acepta únicamente:

```json
{"estado": "inactivo"}
```

## Validaciones y errores

- `codigo_dispositivo`: obligatorio, texto no vacío, máximo 50 caracteres y único.
- `modelo`: opcional, texto o `null`, máximo 100 caracteres.
- `estado`: obligatorio, texto máximo 20 caracteres.
- `id_puesto`: entero positivo y Puesto existente.
- Campos desconocidos, datos incompletos o inválidos: `400` con `error` y
	`detalles`.
- Token ausente, inválido o expirado: `401` mediante la infraestructura JWT.
- Cargo sin permiso: `403`; GUARDIA solo puede consultar y cargos desconocidos
	no reciben privilegios.
- Dispositivo inexistente: `404`.
- Código duplicado o conflicto de integridad: `409`.
- No se añade un handler global `500` en este módulo; los errores inesperados
	conservan el manejo superior existente de Flask.

## Flujo y caché

El flujo es `dispositivos_bp -> cargo_required -> DispositivoService ->
DispositivoRepository -> SQLAlchemy`. Las lecturas usan `CacheService` para el
registro y la colección. Crear, actualizar y cambiar estado invalidan ambas
entradas para evitar datos obsoletos.

## Reglas de negocio

- Cada dispositivo debe tener un identificador único.
- El código del dispositivo debe ser único.
- El puesto asociado debe existir antes de registrar el dispositivo.
- Los campos obligatorios deberán validarse antes de guardar la información.
- Las operaciones deberán devolver respuestas en formato JSON.

## Resultado esperado

El backend y Flutter disponen de un módulo demostrable para listar, crear,
editar y cambiar el estado de dispositivos. Flutter permite seleccionar un
Puesto existente, muestra carga, error con reintento, estado vacío y éxito, y
propaga los errores HTTP mediante `AuthenticatedApiClient`.

## Pruebas realizadas

- Backend: 6 pruebas CRUD, validación, conflicto, inexistencia y autorización.
- Flutter: 3 pruebas del servicio para GET, POST, PUT, PATCH, `id_puesto` y
	errores `400/403/404/409`.
- Flutter: `flutter analyze` sin issues.
