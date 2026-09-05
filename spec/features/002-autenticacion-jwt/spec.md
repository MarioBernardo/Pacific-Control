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
- No existe aun una matriz de permisos por cargo. La infraestructura reusable
  queda centralizada para usarla cuando existan roles y permisos definidos;
  no se inventan cargos ni se restringen acciones por valores no documentados.

- Las contraseñas deberán almacenarse cifradas.
- No se permitirá el acceso mediante credenciales inválidas.
- Las rutas protegidas requerirán un token válido.
- La validación del usuario debe minimizar consultas redundantes a la base de datos, considerando las optimizaciones previstas para el proyecto.

## Resultado esperado

El backend contará con un mecanismo de autenticación seguro que permitirá controlar el acceso a los diferentes módulos del sistema.
