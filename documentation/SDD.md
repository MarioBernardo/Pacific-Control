# Descripción del Diseño de Software - Pacific Control

## 1. Introducción

Pacific Control es un sistema en desarrollo para la gestión de asistencias, turnos y novedades operativas del personal de seguridad. El proyecto está estructurado alrededor de un backend Flask, una base de datos PostgreSQL y una aplicación móvil planificada.

Este documento describe la implementación actual y las funcionalidades documentadas en `spec/`. Las capacidades planificadas se identifican como tales y no se describen como funcionalidades implementadas.

## 2. Propósito

El propósito de Pacific Control es proporcionar una base técnica para registrar y administrar la información del personal operativo, los turnos asignados, los registros de asistencia y las novedades reportadas mediante una API REST que puede ser consumida por una aplicación móvil.

## 3. Alcance

El alcance implementado consiste en la base del backend: inicialización de la aplicación Flask, configuración mediante variables de entorno, integración de SQLAlchemy, migraciones de base de datos y el modelo de dominio inicial.

Los módulos de dominio para empleados, puestos, dispositivos, turnos, asistencias y novedades están especificados, pero sus rutas CRUD, servicios, repositorios y esquemas aún no están implementados. El cliente móvil también está planificado; no existe una implementación móvil en el proyecto.

## 4. Arquitectura General

El proyecto sigue una arquitectura de backend por capas. La fábrica de aplicaciones actual inicializa Flask, carga la configuración, registra las extensiones y expone las rutas disponibles.

La estructura prevista separa las siguientes responsabilidades:

- Models: entidades de persistencia y relaciones.
- Repositories: operaciones de acceso a datos.
- Services: lógica de negocio.
- Routes: manejo de solicitudes HTTP y respuestas JSON.
- Schemas: validación de solicitudes y respuestas.
- Auth: componentes de autenticación.
- Workers: procesamiento de tareas en segundo plano.
- Utils: utilidades compartidas.

Actualmente, existen los modelos y el módulo de rutas base. Las capas restantes están reservadas para las funcionalidades planificadas.

## 5. Componentes de Software

| Componente | Estado actual | Responsabilidad |
| --- | --- | --- |
| Aplicación Flask | Implementado | Crea y configura la aplicación backend. |
| Configuración | Implementado | Carga las variables de entorno y la configuración de la base de datos. |
| SQLAlchemy | Implementado | Define los modelos ORM y la integración con la base de datos. |
| Flask-Migrate / Alembic | Implementado | Gestiona las migraciones del esquema de base de datos. |
| Ruta principal | Implementado | Proporciona la respuesta de estado `GET /`. |
| Módulos CRUD | Planificado | Administran empleados, puestos, dispositivos, turnos, asistencias y novedades. |
| Cliente móvil | Planificado | Consume la API REST. |

## 6. Descripción General de la Base de Datos

PostgreSQL es la base de datos relacional configurada, a la que se accede mediante SQLAlchemy. La migración inicial de Alembic crea las siguientes tablas:

| Tabla | Descripción | Relaciones principales |
| --- | --- | --- |
| `empleados` | Registros del personal. | Tiene turnos, registros de asistencia y novedades. |
| `puestos` | Puestos operativos. | Tiene dispositivos y turnos. |
| `dispositivos` | Dispositivos asignados a puestos. | Pertenece a un puesto; tiene registros de asistencia. |
| `turnos` | Asignaciones de personal por fecha y hora. | Pertenece a un empleado y un puesto; tiene registros de asistencia y novedades. |
| `asistencias` | Registros de asistencia con fecha, hora, ubicación y evidencia opcional. | Pertenece a un empleado, turno y dispositivo. |
| `novedades` | Incidencias operativas. | Pertenece a un empleado y un turno. |

Las claves primarias identifican cada registro. La base de datos aplica las relaciones de claves foráneas documentadas y valores únicos para la identificación y el correo electrónico del empleado, así como para el código del dispositivo.

## 7. Arquitectura del Backend

El punto de entrada del backend es `backend/run.py`, que crea la aplicación mediante `create_app()`. La fábrica de aplicaciones inicializa las extensiones SQLAlchemy y Flask-Migrate, importa los modelos de dominio y registra el blueprint principal.

La configuración se carga desde `backend/.env` mediante `config.py`. La conexión a la base de datos se obtiene de `DATABASE_URL`; la configuración actual incluye valores predeterminados de desarrollo. El backend actualmente se ejecuta en modo de desarrollo de Flask cuando se inicia directamente.

## 8. Descripción General de la API REST

El único endpoint de API implementado es:

| Método | Ruta | Comportamiento actual |
| --- | --- | --- |
| `GET` | `/` | Devuelve una respuesta JSON que identifica a Pacific Control e informa que el backend está funcionando. |

Los endpoints REST para los módulos CRUD están planificados en las funcionalidades 003 a 008. Sus rutas, validaciones, contratos JSON y servicios de negocio aún no están implementados.

## 9. Estrategia de Autenticación

La autenticación está planificada en la funcionalidad 002 y no está implementada. La estrategia prevista utiliza JSON Web Tokens (JWT) para autenticar usuarios, emitir tokens después de validar credenciales y proteger las rutas que requieren autorización.

Actualmente no se encuentra configurada en el backend una biblioteca JWT, un endpoint de inicio de sesión, un modelo de credenciales de usuario ni protección de rutas.

## 10. Estrategia de Rendimiento

Las siguientes capacidades relacionadas con el rendimiento están planificadas y no están implementadas:

- Caché con Redis (funcionalidad 009) para el almacenamiento temporal de resultados de consultas frecuentes, con expiración e invalidación.
- Prevención de N+1 (funcionalidad 010) mediante la carga controlada de las relaciones necesarias de SQLAlchemy.
- Procesamiento asíncrono (funcionalidad 011) mediante Celery y Redis para tareas en segundo plano.
- PgBouncer (funcionalidad 012) para centralizar las conexiones del backend a PostgreSQL.

Estas funcionalidades deben incorporarse después de implementar sus dependencias y las rutas de acceso a datos asociadas.

## 11. Descripción General del Despliegue

El repositorio proporciona actualmente una configuración de backend orientada al desarrollo: un entorno virtual de Python, configuración mediante variables de entorno, conectividad con PostgreSQL y migraciones de Alembic. Al ejecutar `backend/run.py` se inicia el servidor de desarrollo de Flask.

No existe configuración de contenedores, configuración de servidor de producción, definición de orquestación ni canalización de despliegue. Por lo tanto, los detalles del despliegue en producción aún deben definirse.

## 12. Tecnologías Utilizadas

### Implementadas

- Python
- Flask
- Flask-SQLAlchemy
- SQLAlchemy
- PostgreSQL
- Flask-Migrate y Alembic
- python-dotenv
- Git

### Planificadas

- Flutter para el cliente móvil
- Flask-JWT-Extended para la autenticación JWT
- Redis para caché e intermediación de tareas
- Celery para procesamiento asíncrono
- PgBouncer para la administración de conexiones de PostgreSQL
