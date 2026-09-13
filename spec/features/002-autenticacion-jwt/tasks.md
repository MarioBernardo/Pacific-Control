# Tareas

- [ ] Instalar la librería Flask-JWT-Extended.
- [ ] Configurar JWT en el proyecto.
- [ ] Crear el endpoint de inicio de sesión.
- [ ] Validar credenciales del usuario.
- [ ] Generar tokens JWT.
- [ ] Proteger rutas mediante autenticación.
- [ ] Implementar manejo de errores de autenticación.
- [ ] Realizar pruebas con Postman.
- [ ] Documentar la implementación.

## Implementado y probado en AUTH-01 + SEC-01

- [x] Login JWT con validacion de credenciales y hash de contrasena.
- [x] Rechazo de empleados inactivos durante el login.
- [x] Proteccion JWT de POST, GET, PUT y PATCH de los seis CRUD.
- [x] Respuesta JSON uniforme para token ausente, invalido o expirado.
- [x] Respuesta 403 para empleado autenticado inactivo.
- [x] Pruebas automatizadas de login, JWT, POST protegido y empleado inactivo.

## Pendiente

- [ ] Ejecutar pruebas manuales con Postman.
- [x] Definir una matriz explícita para ADMINISTRADOR, SUPERVISOR y GUARDIA.
- [x] Centralizar la autorización y rechazar cargos desconocidos sin privilegios.
- [x] Crear seed idempotente de usuarios activos e inactivos con contraseñas hasheadas.
- [x] Probar login, estado activo y permisos por rol.
- [ ] Implementar refresh, revocacion o rotacion de tokens si el alcance futuro lo requiere.

## Estado

🚧 En desarrollo
