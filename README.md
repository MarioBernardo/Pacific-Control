# Pacific Control

## Descripción

Pacific Control es un sistema desarrollado para optimizar la gestión operativa de una empresa de seguridad privada mediante una aplicación móvil y una API REST. El sistema permite administrar empleados, puestos, dispositivos, turnos, asistencias y novedades, garantizando un control eficiente de las operaciones y facilitando el seguimiento en tiempo real.

El sistema está compuesto por un **backend/API REST desarrollado con Flask** y una **aplicación móvil desarrollada con Flutter**. El backend utiliza una arquitectura por capas, autenticación mediante JWT, almacenamiento en caché con Redis y procesamiento asíncrono con Celery.

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

## Tecnologías móviles

| Tecnología | Uso en el proyecto |
|------------|--------------------|
| Flutter | Desarrollo de la aplicación móvil. |
| Dart | Lenguaje de programación de Flutter. |
| Android Studio | Ejecución y administración del entorno Android. |
| Android Emulator | Pruebas de la aplicación móvil contra el backend local. |
| HTTP | Consumo de la API REST de Flask. |
| flutter_secure_storage | Almacenamiento seguro de la sesión y del token JWT. |

---

## Estructura general del proyecto

```text
Pacific-Control/
├── backend/
├── mobile/
├── documentation/
└── spec/
```

- `backend/`: API REST en Flask, modelos, servicios, rutas, migraciones y configuración.
- `mobile/`: aplicación Flutter para Android y otras plataformas compatibles.
- `documentation/`: documentación técnica y de arquitectura del proyecto.
- `spec/`: especificaciones y planificación de funcionalidades.

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

## Configuración y ejecución del backend

## Clonar el repositorio

```bash
git clone <URL_DEL_REPOSITORIO>
```

## Ingresar al backend

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

## Ejecutar el backend

```bash
python run.py
```

Flask queda disponible en el puerto `5000` y escucha en `0.0.0.0`, lo que permite el acceso desde el emulador Android mediante `10.0.2.2`.

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

## Configuración y ejecución de la aplicación móvil

Desde la raíz del proyecto, ingresa a la aplicación móvil e instala sus dependencias:

```bash
cd mobile
flutter pub get
flutter devices
```

Para ejecutar la aplicación en el emulador Android:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

La dirección `10.0.2.2` permite que el emulador Android acceda al servidor Flask que se ejecuta en el computador anfitrión.

---

## Conexión Flutter - Flask

Flutter consume la API REST del backend mediante HTTP. La conectividad inicial se verifica con:

```text
GET /
```

Una respuesta JSON correcta confirma que el backend está funcionando y que el emulador puede comunicarse con Flask.

---

## Autenticación móvil

El flujo de autenticación implementado es:

```text
LoginPage
    ↓
POST /auth/login
    ↓
Flask valida correo y contraseña
    ↓
JWT access_token
    ↓
Flutter almacena la sesión de forma segura
    ↓
HomePage
```

El inicio de sesión envía:

```json
{
  "correo": "usuario@empresa.com",
  "password": "********"
}
```

Una autenticación exitosa devuelve el `access_token` y los datos del empleado. Flutter conserva la sesión mediante almacenamiento seguro.

---

## Interfaz móvil

La aplicación móvil cuenta actualmente con:

- Pantalla de inicio de sesión.
- Campos de usuario y contraseña.
- Validación de formulario y mensajes de error.
- Opción para mostrar u ocultar la contraseña.
- Diseño basado en los colores corporativos de Pacific Control.
- Logotipo de Pacific Security Force.
- Pantalla principal después de autenticarse.
- Cierre de sesión.

---

## Logo y recursos gráficos

El logotipo oficial se encuentra en:

```text
mobile/assets/branding/
```

El directorio está declarado como asset en `mobile/pubspec.yaml` y el logo se muestra conservando sus proporciones originales.

---

## Verificación del proyecto

Para comprobar el análisis estático y las pruebas de Flutter:

```bash
flutter analyze
flutter test
```

Para revisar problemas de espacios o formato en los cambios del repositorio:

```bash
git diff --check
```

---

## Flujo completo de ejecución

1. Iniciar PostgreSQL y los servicios locales necesarios, como Redis cuando esté habilitado.
2. Iniciar el backend Flask desde `backend/`.
3. Verificar que Flask está escuchando en el puerto `5000`.
4. Iniciar el emulador Android.
5. Ejecutar Flutter indicando `API_BASE_URL=http://10.0.2.2:5000`.
6. Verificar la conexión con el backend mediante `GET /`.
7. Realizar el inicio de sesión.
8. Verificar el acceso a la pantalla principal.
9. Probar el cierre de sesión.

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
- Backend/API REST funcional y CRUD implementados.
- Autenticación JWT.
- Redis Cache.
- Celery.
- PostgreSQL.
- Migraciones.
- Aplicación móvil Flutter.
- Conexión Flutter ↔ Flask.
- Login móvil funcional.
- Sesión segura.
- Interfaz móvil con diseño corporativo.

---

# Autor

**Mario David Bernardo Campo**

Universidad Estatal Amazónica

Carrera de Tecnologías de la Información

Proyecto académico desarrollado para la asignatura de Desarrollo de Aplicaciones Móviles.

---

## Video de demostración

El video de demostración será incorporado posteriormente como parte de la entrega.
