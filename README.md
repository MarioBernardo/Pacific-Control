# Pacific Control - Backend

## Descripción

Pacific Control es un sistema desarrollado para optimizar la gestión operativa de una empresa de seguridad privada mediante una aplicación móvil y una API REST. El sistema permite administrar empleados, puestos, dispositivos, turnos, asistencias y novedades, garantizando un control eficiente de las operaciones y facilitando el seguimiento en tiempo real.

El backend fue desarrollado utilizando una arquitectura por capas, implementando buenas prácticas de desarrollo como separación de responsabilidades, autenticación mediante JWT, almacenamiento en caché con Redis y procesamiento asíncrono con Celery.

---

## Objetivos del Proyecto

- Digitalizar el registro de asistencia del personal operativo.
- Administrar la asignación de puestos y dispositivos.
- Gestionar turnos de trabajo.
- Registrar novedades e incidencias en tiempo real.
- Mejorar el rendimiento de la API mediante almacenamiento en caché.
- Implementar una arquitectura escalable y mantenible.

---

# Tecnologías Utilizadas

| Tecnología | Descripción |
|------------|-------------|
| Python 3 | Lenguaje de programación |
| Flask | Framework para la API REST |
| SQLAlchemy | ORM para acceso a la base de datos |
| PostgreSQL | Sistema gestor de base de datos |
| Flask-Migrate (Alembic) | Control de migraciones |
| Redis | Sistema de almacenamiento en caché |
| Celery | Procesamiento de tareas asíncronas |
| Flask-JWT-Extended | Autenticación mediante JSON Web Tokens |
| python-dotenv | Gestión de variables de entorno |
| Git | Control de versiones |
| GitHub | Repositorio del proyecto |

---

# Arquitectura del Proyecto

El backend implementa una arquitectura basada en **Application Factory** y separación por capas para facilitar el mantenimiento y la escalabilidad.

```
backend/
│
├── app/
│   ├── auth/
│   ├── models/
│   ├── repositories/
│   ├── routes/
│   ├── services/
│   ├── cache.py
│   ├── celery_app.py
│   ├── extensions.py
│   └── tasks.py
│
├── migrations/
├── tests/
├── config.py
├── requirements.txt
└── run.py
```

La aplicación está organizada utilizando:

- Application Factory
- Blueprints
- Repository Pattern
- Service Pattern
- SQLAlchemy ORM
- JWT Authentication
- Redis Cache Aside
- Celery para procesamiento asíncrono

---

# Funcionalidades

El sistema permite administrar la siguiente información:

- Gestión de empleados.
- Gestión de puestos de trabajo.
- Gestión de dispositivos móviles.
- Gestión de turnos.
- Registro de asistencias.
- Registro de novedades.
- Autenticación mediante JWT.
- Protección de endpoints.
- Almacenamiento en caché con Redis.
- Procesamiento asíncrono mediante Celery.

---

# Seguridad

El backend implementa autenticación basada en JSON Web Tokens (JWT).

Características:

- Inicio de sesión seguro.
- Generación de Access Token.
- Protección de endpoints mediante `@jwt_required()`.
- Contraseñas almacenadas utilizando hash.
- Tokens enviados mediante el encabezado Authorization Bearer.

---

# Caché

Se implementó el patrón **Cache Aside** utilizando Redis para optimizar consultas frecuentes y reducir el acceso repetitivo a la base de datos.

Beneficios:

- Menor tiempo de respuesta.
- Reducción de carga sobre PostgreSQL.
- Invalidación automática del caché cuando existen cambios en la información.

---

# Procesamiento Asíncrono

Se implementó Celery para ejecutar tareas que no requieren respuesta inmediata al usuario.

Esto permite:

- Mejorar el rendimiento de la API.
- Procesar tareas en segundo plano.
- Facilitar la escalabilidad del sistema.

---

# Base de Datos

Motor utilizado:

- PostgreSQL

Acceso mediante:

- SQLAlchemy ORM

Control de versiones:

- Flask-Migrate
- Alembic

---

# Instalación

## Clonar el repositorio

```bash
git clone <URL_DEL_REPOSITORIO>
```

## Ingresar al proyecto

```bash
cd backend
```

## Crear entorno virtual

```bash
python -m venv venv
```

## Activar entorno virtual

Windows:

```bash
venv\Scripts\activate
```

Linux/macOS:

```bash
source venv/bin/activate
```

## Instalar dependencias

```bash
pip install -r requirements.txt
```

---

# Variables de Entorno

Crear un archivo `.env` con la siguiente configuración:

```env
SECRET_KEY=tu_secret_key
JWT_SECRET_KEY=tu_jwt_secret
DATABASE_URL=postgresql://usuario:password@localhost:5432/pacific_control
REDIS_URL=redis://localhost:6379/0
CACHE_ENABLED=true
CACHE_DEFAULT_TTL=300
```

---

# Migraciones

Crear migraciones:

```bash
flask db migrate -m "Nueva migración"
```

Aplicar migraciones:

```bash
flask db upgrade
```

---

# Ejecutar el Proyecto

```bash
python run.py
```

---

# Endpoints Principales

- Autenticación
- Empleados
- Puestos
- Dispositivos
- Turnos
- Asistencias
- Novedades

Todos los endpoints protegidos requieren un token JWT válido.

---

# Buenas Prácticas Implementadas

- Arquitectura por capas.
- Separación de responsabilidades.
- Repository Pattern.
- Service Pattern.
- Variables de entorno.
- Autenticación JWT.
- Cache Aside.
- Procesamiento asíncrono.
- Migraciones con Alembic.
- Organización modular mediante Blueprints.

---

# Estado del Proyecto

**Versión:** 1.0

Estado actual:

- Arquitectura implementada.
- CRUD completo.
- Autenticación JWT.
- Redis Cache.
- Celery.
- PostgreSQL.
- Migraciones.
- API REST funcional.

---

# Autor

**Mario David Bernardo Campo**

Universidad Estatal Amazónica

Carrera de Tecnologías de la Información

Proyecto académico desarrollado para la asignatura de Desarrollo de Aplicaciones Móviles.