# 002 - Autenticación JWT

## Objetivo

Implementar un mecanismo de autenticación basado en JSON Web Token (JWT) para controlar el acceso a los recursos protegidos del backend del proyecto Pacific Control.

## Alcance

Este feature comprende:

- Implementación del inicio de sesión.
- Generación de tokens JWT.
- Protección de rutas mediante autenticación.
- Validación de usuarios autenticados.
- Manejo de respuestas de autenticación.

## Dependencias

- Flask
- Flask-JWT-Extended
- PostgreSQL
- SQLAlchemy

## Resultado esperado

El sistema permitirá autenticar usuarios mediante credenciales válidas y protegerá los servicios que requieran autorización mediante tokens JWT.