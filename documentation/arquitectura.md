# Arquitectura del Backend

## 1. Arquitectura por capas

El backend de Pacific Control adopta una organización por capas dentro de `backend/app`. Esta organización separa la atención de solicitudes HTTP, la lógica de negocio, el acceso a datos y la representación persistente del dominio. Su objetivo es mantener responsabilidades acotadas y evitar dependencias directas entre la interfaz HTTP y la persistencia.

La estructura está parcialmente implementada. Las capas de modelos, extensiones y rutas base tienen contenido funcional; las capas de repositorios, servicios, esquemas, autenticación, workers y utilidades existen como directorios preparados para su incorporación posterior. Por tanto, la arquitectura define tanto los componentes activos como los límites previstos para el crecimiento del backend.

## 2. Responsabilidad de cada capa

| Capa | Responsabilidad arquitectónica | Estado actual |
| --- | --- | --- |
| `models` | Representar entidades persistentes y sus relaciones mediante el ORM. | Implementada. |
| `repositories` | Encapsular las operaciones de acceso y consulta de datos. | Directorio preparado, sin implementación. |
| `services` | Concentrar reglas de negocio y coordinar repositorios. | Directorio preparado, sin implementación. |
| `routes` | Recibir solicitudes HTTP, delegar el procesamiento y devolver respuestas. | Implementación base disponible. |
| `schemas` | Validar datos de entrada y estructurar datos de salida. | Directorio preparado, sin implementación. |
| `auth` | Aislar los componentes de autenticación y autorización. | Directorio preparado, sin implementación. |
| `workers` | Alojar los procesos de tareas en segundo plano. | Directorio preparado, sin implementación. |
| `utils` | Centralizar utilidades reutilizables sin responsabilidad de dominio. | Directorio preparado, sin implementación. |

La separación prevista establece que las rutas no deben acceder directamente a los modelos para resolver operaciones de negocio. Cuando se implementen los módulos funcionales, las rutas deberán delegar en servicios y los servicios deberán utilizar repositorios para la persistencia. Los modelos permanecerán como la representación del estado persistente.

## 3. Flujo de una petición HTTP

El flujo implementado comienza en el servidor Flask creado desde `backend/run.py`. La aplicación se construye por medio de la fábrica ubicada en `backend/app/__init__.py`, que registra el blueprint principal.

Para la ruta disponible, el procesamiento sigue esta secuencia:

1. Flask recibe la solicitud HTTP.
2. El enrutador identifica la ruta registrada en el blueprint `main_bp`.
3. La función de ruta genera una respuesta JSON básica.
4. Flask serializa y devuelve la respuesta al cliente.

El flujo completo por capas aún no se ejecuta porque no existen rutas de negocio, servicios, repositorios ni esquemas implementados. La secuencia prevista para dichas rutas es: solicitud HTTP, ruta, validación, servicio, repositorio, modelo, respuesta JSON. Esta secuencia describe la organización arquitectónica esperada, no un flujo actualmente activo.

## 4. Estructura de carpetas del backend

| Ruta | Responsabilidad |
| --- | --- |
| `backend/run.py` | Punto de entrada del backend y creación de la aplicación. |
| `backend/config.py` | Definición centralizada de la configuración de la aplicación. |
| `backend/requirements.txt` | Dependencias Python del backend. |
| `backend/app/__init__.py` | Fábrica de aplicaciones y composición de los componentes principales. |
| `backend/app/extensions.py` | Instancias compartidas de extensiones Flask. |
| `backend/app/models/` | Modelos ORM y módulo de importación del dominio. |
| `backend/app/routes/` | Blueprints y controladores HTTP. |
| `backend/app/repositories/` | Ubicación prevista para el acceso a datos. |
| `backend/app/services/` | Ubicación prevista para la lógica de negocio. |
| `backend/app/schemas/` | Ubicación prevista para validación y serialización. |
| `backend/app/auth/` | Ubicación prevista para componentes de autenticación. |
| `backend/app/workers/` | Ubicación prevista para tareas en segundo plano. |
| `backend/app/utils/` | Ubicación prevista para utilidades compartidas. |
| `backend/migrations/` | Entorno Alembic, configuración de migraciones y versiones del esquema. |

Los directorios preparados no deben interpretarse como módulos funcionales. En el estado actual, solo `models/`, `routes/`, `extensions.py` y la fábrica de aplicaciones contienen componentes de ejecución del backend.

## 5. Patrones de diseño utilizados

### Application Factory

El patrón Application Factory está implementado mediante `create_app()`. La función concentra la creación de la instancia Flask y la composición de la aplicación: carga la configuración, inicializa las extensiones y registra el blueprint disponible.

Este patrón evita que la inicialización dependa de efectos globales al importar módulos y proporciona un punto único para incorporar componentes futuros. También permite que las extensiones se declaren de forma desacoplada en `extensions.py` y se vinculen a la aplicación durante su creación.

### Arquitectura Repository/Service prevista

La presencia de los directorios `repositories/` y `services/` establece una arquitectura Repository/Service prevista, no implementada. En este diseño, un repositorio debe aislar el uso de SQLAlchemy y un servicio debe contener la lógica que combina operaciones y aplica reglas del dominio.

La aplicación actual no contiene clases, funciones ni flujos que materialicen estos patrones. Su inclusión en la estructura define el límite de responsabilidades que deben respetar las futuras implementaciones, sin atribuir comportamiento inexistente al backend actual.

## 6. Tecnologías utilizadas

| Tecnología | Uso dentro de la arquitectura |
| --- | --- |
| Python | Lenguaje de implementación del backend. |
| Flask | Framework web que crea la aplicación, gestiona rutas y responde solicitudes HTTP. |
| Flask-SQLAlchemy | Integración de SQLAlchemy con el ciclo de vida de Flask. |
| SQLAlchemy | Mapeo objeto-relacional y definición de los modelos persistentes. |
| PostgreSQL | Motor de base de datos utilizado por la configuración del backend. |
| Flask-Migrate | Integración de migraciones con Flask. |
| Alembic | Motor de versionado de migraciones utilizado por Flask-Migrate. |
| psycopg2-binary | Controlador de conexión de Python para PostgreSQL. |
| python-dotenv | Carga de variables de entorno desde el archivo de configuración local. |

Las versiones de estas dependencias se declaran en `backend/requirements.txt`.

## 7. Ventajas de la arquitectura

La organización actual ofrece las siguientes ventajas:

- **Separación de responsabilidades:** la estructura diferencia la interfaz HTTP, la persistencia y la lógica de negocio prevista, lo que reduce el acoplamiento entre capas.
- **Inicialización controlada:** Application Factory concentra el ensamblaje de la aplicación y de sus extensiones en un único punto.
- **Extensibilidad:** los directorios preparados permiten incorporar repositorios, servicios, esquemas, autenticación y workers sin reorganizar la base del backend.
- **Mantenibilidad:** la ubicación definida para cada responsabilidad facilita localizar componentes y limitar cambios a la capa correspondiente.
- **Consistencia técnica:** el uso compartido de extensiones evita crear configuraciones paralelas de SQLAlchemy o Flask-Migrate.
- **Evolución verificable:** el aislamiento entre modelos, migraciones y futuras capas de acceso a datos permite ampliar el backend de forma incremental.

Estas ventajas describen la estructura existente y su capacidad de evolución. Las ventajas asociadas a Repository/Service serán efectivas cuando esas capas cuenten con una implementación concreta.
