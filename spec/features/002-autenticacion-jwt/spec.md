# Especificación Técnica - Autenticación JWT

## Descripción

Este feature implementa un mecanismo de autenticación utilizando JSON Web Token (JWT), permitiendo identificar usuarios válidos y restringir el acceso a los recursos protegidos del sistema.

## Componentes involucrados

- Auth
- Routes
- Services
- Repositories
- Models

## Flujo general

1. El usuario envía sus credenciales.
2. El sistema valida la información contra la base de datos.
3. Si las credenciales son válidas, se genera un token JWT.
4. El cliente utiliza el token para acceder a los recursos protegidos.
5. Cada solicitud protegida valida el token antes de ejecutar la operación solicitada.

## Consideraciones

- Las contrasenas se validan contra un hash y los errores de credenciales no
  revelan si el correo existe o si el empleado esta inactivo.
- Las rutas protegidas requieren un Bearer access token valido y un empleado
  que permanezca activo en la base de datos.
- Token ausente, invalido o expirado responde JSON con HTTP 401. Un empleado
  autenticado pero inactivo recibe HTTP 403 sin cerrar su sesion.
- El cargo se usa como rol únicamente cuando coincide, después de normalizarlo,
  con ADMINISTRADOR, SUPERVISOR o GUARDIA. Un cargo vacío, legacy o desconocido
  no obtiene privilegios.
- ADMINISTRADOR puede administrar todos los recursos. SUPERVISOR puede consultar
  empleados y gestionar la operación, pero no modificar empleados. GUARDIA puede
  consultar la información operativa y crear asistencias o novedades, pero no
  administrar empleados ni la configuración.
- La autorización se centraliza en `cargo_required`, que primero exige JWT
  válido y empleado activo. El rol se obtiene del empleado actual en la base de
  datos, no de un valor no verificado del token.

- Las contraseñas deberán almacenarse cifradas.
- No se permitirá el acceso mediante credenciales inválidas.
- Las rutas protegidas requerirán un token válido.
- La validación del usuario debe minimizar consultas redundantes a la base de datos, considerando las optimizaciones previstas para el proyecto.

## Resultado esperado

El backend contará con un mecanismo de autenticación seguro que permitirá controlar el acceso a los diferentes módulos del sistema.

## Usuarios de prueba

El seed idempotente `seed_demo_users()` crea o actualiza estas cuentas:

| Correo | Rol | Estado | Contraseña |
|---|---|---|---|
| admin@pacific.test | ADMINISTRADOR | Activo | Admin123! |
| supervisor@pacific.test | SUPERVISOR | Activo | Supervisor123! |
| guardia@pacific.test | GUARDIA | Activo | Guardia123! |
| inactivo@pacific.test | GUARDIA | Inactivo | Inactivo123! |

Las contraseñas se almacenan únicamente como hash.

## Respuestas HTTP verificadas

- `400`: JSON ausente o datos inválidos.
- `401`: credenciales incorrectas, token ausente, inválido o expirado.
- `403`: empleado inactivo o rol sin permiso.
- `404`: recurso inexistente.
- `409`: conflicto de datos o duplicado.
- `500`: error interno controlado por la aplicación cuando aplica.
