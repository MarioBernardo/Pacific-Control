# Constitución del Proyecto Pacific Control

## Propósito

Pacific Control es un sistema orientado a la gestión operativa de empresas de seguridad privada. Su objetivo es optimizar el control de empleados, puestos de vigilancia, turnos, asistencias, dispositivos y novedades mediante una aplicación móvil y un backend seguro y escalable.

---

## Principios del proyecto

### 1. Arquitectura por capas

El sistema mantiene una separación clara entre rutas, servicios, repositorios y modelos para facilitar el mantenimiento y la escalabilidad.

### 2. Seguridad

Todas las rutas privadas deben protegerse mediante autenticación basada en JWT.

### 3. Calidad del código

El código debe seguir buenas prácticas de programación, mantener responsabilidades separadas y utilizar nombres descriptivos.

### 4. Rendimiento

Las consultas frecuentes podrán optimizarse utilizando Redis mediante el patrón Cache Aside y las tareas de larga duración deberán ejecutarse mediante Celery.

### 5. Persistencia

Toda la información será almacenada en PostgreSQL utilizando SQLAlchemy como ORM.

### 6. Escalabilidad

La arquitectura permitirá incorporar nuevos módulos sin afectar las funcionalidades existentes.

### 7. Documentación

Toda funcionalidad nueva deberá estar documentada dentro de la carpeta `spec` antes de su implementación.

---

## Tecnologías oficiales

- Flask
- PostgreSQL
- SQLAlchemy
- Redis
- Celery
- JWT
- Python

---

## Objetivo general

Desarrollar un backend seguro, organizado y escalable que permita administrar la información operativa del sistema Pacific Control siguiendo buenas prácticas de arquitectura y desarrollo de software.