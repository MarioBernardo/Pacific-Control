# Cierre administrativo y control operativo — Semana 14

## Alcance implementado

El panel administrativo conserva la autenticación JWT y los permisos existentes. Las listas de asistencias, novedades, turnos y dispositivos entregan datos humanos relacionados en la misma consulta: guardia, puesto, tipo de turno/asignación y dispositivo, sin efectuar una petición por fila.

Se incorporaron tres lecturas protegidas para `ADMINISTRADOR` y `SUPERVISOR`:

- `GET /reportes/dashboard`: indicadores del día y una vista breve del personal en turno.
- `GET /reportes/personal-en-turno`: guardias cuya última asistencia válida sigue dentro de las 12 o 24 horas de su turno.
- `GET /reportes/guardias/<id>/resumen-mensual?mes=<1-12>&anio=<año>`: asistencias válidas, desglose 12/24, horas derivadas, puestos cubiertos y novedades.

La determinación de personal en turno es reproducible: se ordenan marcaciones de la más reciente a la más antigua, se conserva una por guardia y se excluyen estados anulados, cancelados o inactivos. La hora estimada de fin se obtiene sumando 12 o 24 horas a la marcación real; no se crea estado adicional ni se modifica el modelo de datos.

## Interfaz

- El inicio administrativo presenta guardias en turno, asistencias del día, novedades abiertas y puestos cubiertos.
- Asistencias y novedades muestran nombres y fechas legibles y ofrecen detalle completo.
- La evidencia fotográfica se descarga mediante un endpoint autenticado y nunca expone una ruta física.
- Turnos y dispositivos muestran nombres de empleado y puesto, no identificadores técnicos.
- Desde Personal en turno y desde la gestión de guardias se accede al resumen mensual.
- Estados vacíos, fallos de red y reintentos se presentan de forma explícita.

## Seguridad y rendimiento

Los endpoints administrativos exigen los cargos autorizados. Las relaciones usadas en listas y reportes se cargan con `joinedload`, evitando el patrón N+1. La evidencia valida que el archivo resuelto permanezca dentro del directorio configurado antes de enviarlo. No se agregaron migraciones: las nuevas relaciones ORM utilizan claves foráneas que ya existían.

## Validación manual pendiente

Además de las suites automatizadas, queda pendiente validar en un dispositivo físico el recorrido completo: login administrativo, indicadores, detalle de asistencia, detalle/evidencia de novedad, personal en turno y resumen mensual. Los sensores y permisos nativos continúan documentados en `SEMANA_14_FUNCIONES_NATIVAS.md`.
