# Especificación Técnica - CRUD Puestos

## Descripción

Este feature implementa el módulo encargado de administrar la información de los puestos registrados en el sistema Pacific Control.

## Componentes involucrados

- Models
- Repositories
- Services
- Routes
- Schemas

## Funcionalidades

- Registrar un puesto.
- Consultar un puesto por su identificador.
- Listar todos los puestos.
- Actualizar la información de un puesto.
- Cambiar el estado de un puesto.

## Endpoints reales

Todos los endpoints requieren un Bearer JWT de un empleado activo.

| Método | Ruta | Permiso | Respuesta exitosa |
|---|---|---|---|
| POST | `/puestos` | ADMINISTRADOR, SUPERVISOR | `201` con `data` |
| GET | `/puestos` | ADMINISTRADOR, SUPERVISOR, GUARDIA | `200` con lista `data` |
| GET | `/puestos/<id_puesto>` | ADMINISTRADOR, SUPERVISOR, GUARDIA | `200` con `data` |
| PUT | `/puestos/<id_puesto>` | ADMINISTRADOR, SUPERVISOR | `200` con `data` |
| PATCH | `/puestos/<id_puesto>/estado` | ADMINISTRADOR, SUPERVISOR | `200` con `data` |

No existe eliminación física; el cambio de estado implementa la baja lógica
prevista por el modelo actual.

### Body de creación y actualización

```json
{
	"nombre_puesto": "Garita Norte",
	"direccion": "Av. Principal 100",
	"estado": "activo"
}
```

`POST` exige los tres campos. `PUT` acepta uno o más campos y `PATCH` acepta
únicamente `estado`. Los textos se recortan y se validan con los límites del
modelo: 100 caracteres para el nombre, 200 para la dirección y 20 para el
estado.

## Reglas de negocio

- Cada puesto debe tener un identificador único.
- Los campos obligatorios deberán validarse antes de guardar la información.
- No se permitirá registrar información incompleta.
- Las operaciones deberán devolver respuestas en formato JSON.

## Errores y autorización

- `400`: JSON ausente, campos requeridos ausentes, campos desconocidos o datos
	inválidos.
- `401`: token ausente, inválido o expirado.
- `403`: empleado inactivo, GUARDIA intentando mutar o cargo desconocido.
- `404`: puesto inexistente en consulta, actualización o cambio de estado.
- `409`: conflicto de persistencia si la base de datos rechaza la operación.
- `500`: error inesperado controlado por las capas superiores de la aplicación.

El flujo es `Blueprint -> cargo_required -> PuestoService -> PuestoRepository ->
SQLAlchemy`. Las lecturas utilizan `CacheService`; las mutaciones invalidan la
entrada individual y la colección para evitar listados obsoletos.

## Resultado esperado

El backend y la aplicación Flutter disponen de un módulo demostrable para
consultar, crear, editar y cambiar el estado de puestos. Flutter muestra estados
de carga, error con reintento, lista vacía, listado exitoso y errores HTTP
comprensibles mediante `AuthenticatedApiClient`.

## Pruebas realizadas

- Backend: 5 pruebas CRUD/autorización de Puestos.
- Flutter: 3 pruebas del servicio de Puestos.
- Flutter: `flutter analyze` sin issues.
