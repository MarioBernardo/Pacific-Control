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
- [ ] Definir una matriz de permisos por cargo basada en roles reales.
- [ ] Implementar refresh, revocacion o rotacion de tokens si el alcance futuro lo requiere.

## Estado

🚧 En desarrollo
