# Especificación Técnica - CRUD Novedades

## Descripción

Este feature implementa el módulo encargado de administrar las novedades registradas durante la operación en el sistema Pacific Control.

## Componentes involucrados

- Models
- Repositories
- Services
- Routes
- Schemas

## Funcionalidades

- Registrar una novedad.
- Consultar una novedad por su identificador.
- Listar todas las novedades.
- Actualizar la información de una novedad.
- Cambiar el estado de una novedad.
- Asociar una novedad a un empleado y un turno.

## Reglas de negocio

- Cada novedad debe tener un identificador único.
- El empleado y el turno asociados deben existir antes de registrar la novedad.
- El tipo, descripción y fecha de la novedad deberán registrarse de forma obligatoria.
- Los campos obligatorios deberán validarse antes de guardar la información.
- Las operaciones deberán devolver respuestas en formato JSON.

## Resultado esperado

El backend dispondrá de un módulo completo para la administración de novedades mediante una API REST organizada y preparada para integrarse con los demás módulos del sistema.
