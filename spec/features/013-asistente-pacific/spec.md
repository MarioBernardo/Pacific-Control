# Especificación — ASISTENTE PACIFIC

## Requisitos funcionales

- ADMINISTRADOR y SUPERVISOR pueden formular preguntas operativas en lenguaje natural.
- El contexto proviene de dashboard, personal, asistencias, novedades y resumen de guardia.
- La respuesta identifica texto, datos utilizados y fuentes internas.
- Preguntas vacías o mayores a 500 caracteres son rechazadas.
- Proveedor ausente o fallido produce un error controlado y permite reintentar.

## Requisitos no funcionales

- JWT y empleado activo obligatorios; GUARDIA y sesión operativa no acceden.
- API key solo en backend y nunca en logs, respuestas o Flutter.
- Sin SQL, comandos o herramientas arbitrarias generadas por el modelo.
- Timeout configurable; pruebas sin Internet ni consumo de créditos.
- Respuestas basadas exclusivamente en contexto real allowlist.
- Gemini API es el proveedor de demostración; modelo, base URL y timeout son configurables en backend.

## Criterios de aceptación

El endpoint `POST /agente/consultar` devuelve contrato estructurado, maneja 400/401/403/502/503 y la pantalla Flutter cubre loading, respuesta, error y nueva consulta.
