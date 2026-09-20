# Semana 14: login operativo y funciones nativas

## Objetivo y alcance

Pacific Control inicia en una única portada institucional. Desde el campo Usuario determina el tipo de cuenta y dirige al flujo administrativo JWT o al acceso operativo por puesto/dispositivo. La geolocalización puntual al registrar asistencia y la fotografía opcional al reportar novedades se conservan. No existe seguimiento en segundo plano, galería, video ni múltiples fotos.

## Flujo operativo

1. En la portada institucional, el dispositivo inicia sesión con usuario y contraseña del puesto y entra al Inicio Operativo.
2. El backend valida el hash y emite un token opaco de vinculación, almacenado en `flutter_secure_storage`.
3. El Inicio Operativo muestra puesto, dispositivo, estado y guardia actual. Desde allí se selecciona un guardia asignado al puesto y un turno `12 HORAS` o `24 HORAS`.
4. `Cambiar guardia` elimina solamente la identificación temporal en Redis.
5. `Cerrar sesión del dispositivo` invalida el vínculo backend, limpia guardia y almacenamiento seguro local.

El token anterior `X-Device-Token` se conserva para compatibilidad/aprovisionamiento interno, pero la interfaz final no lo muestra. La cuenta operativa no crea JWT ni concede acceso administrativo.

## Cuentas demo

| Usuario | Contraseña demo | Dispositivo | Puesto |
|---|---|---|---|
| `baviera` | `BavieraOperativa2026!` | BAVIERA-01 | ED. BAVIERA |
| `century` | `CenturyOperativa2026!` | CENTURY-01 | ED. CENTURY PLAZA I |
| `grandvictoria` | `GrandVictoriaOperativa2026!` | GRAND-VICTORIA-01 | ED. GRAND VICTORIA |
| `vertice` | `VerticeOperativa2026!` | VERTICE-01 | ED. VERTICE |

Solo se persisten hashes Werkzeug en PostgreSQL. Las contraseñas no se guardan en el teléfono.

## Plugins seleccionados

| Plugin | Restricción usada | Uso y criterio |
|---|---:|---|
| `geolocator` | `^14.0.2` | Posición puntual, estado del servicio y ajustes; compatible con Dart 3.13 y `flutter_secure_storage 9.2.4`. |
| `image_picker` | `^1.2.1` (resuelto 1.2.3) | Captura simple mediante `ImageSource.camera`, sin complejidad de una UI de cámara propia. |
| `permission_handler` | `12.0.3` | Distingue concedido, denegado y permanente y abre ajustes; es la última versión estable compatible con `compileSdk 36` (resuelve `permission_handler_android 13.0.1`). |
| `flutter_secure_storage` | `^9.2.4` | Conserva token opaco e id del dispositivo cifrados por plataforma. |

Se verificaron paquetes mantenidos en pub.dev, soporte Android/iOS y resolución real de dependencias. `geolocator 14.0.3` no se adoptó porque entra en conflicto con la versión Windows de `flutter_secure_storage`; 14.0.2 resolvió correctamente.

## Permisos y momento de solicitud

Android declara solamente:

- `android.permission.INTERNET`
- `android.permission.ACCESS_COARSE_LOCATION`
- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.CAMERA`

No se declara ubicación en segundo plano ni permisos de almacenamiento/galería. iOS declara:

- `NSLocationWhenInUseUsageDescription`: "Pacific Control usa tu ubicación al registrar la asistencia para conservar evidencia del lugar de marcación."
- `NSCameraUsageDescription`: "Pacific Control utiliza la cámara para adjuntar evidencia fotográfica a las novedades."

La ubicación se pide solo al confirmar `Registrar`; la cámara solo al pulsar `Tomar fotografía`. Ambos flujos muestran primero una explicación con Continuar/Cancelar. Un permiso no solicitado pasa por la solicitud nativa; concedido continúa; denegado informa y permite reintentar; permanentemente denegado ofrece `ABRIR AJUSTES`.

La asistencia comprueba primero que el servicio GPS esté activo, después resuelve el permiso y finalmente solicita una posición puntual. `getCurrentPosition` y el controlador aplican un timeout de 15 segundos. Todos los resultados restauran el loading mediante `finally`; nunca se envía la asistencia sin coordenadas reales.

## Degradación

| Capacidad | Situación | Comportamiento |
|---|---|---|
| Ubicación (esencial) | Concedida y GPS activo | Obtiene coordenadas y registra asistencia. |
| Ubicación | Denegada | Informa y permite reintentar; no crea una marcación falsa. |
| Ubicación | Denegada permanentemente | Explica y ofrece Abrir ajustes. |
| Ubicación | GPS apagado | Lo distingue del permiso y ofrece abrir ajustes de ubicación. |
| Ubicación | Error | Mensaje controlado y reintento. |
| Cámara (opcional) | Concedida | Captura, previsualiza, repite o quita una foto. |
| Cámara | Denegada | Informa y permite enviar sin foto. |
| Cámara | Denegada permanentemente | Ofrece ajustes o continuar sin foto. |
| Cámara | Cancelada/no disponible/error | Conserva el formulario y permite enviar sin foto. |

## Persistencia e integración

- Local: token opaco e id en almacenamiento seguro; coordenadas y ruta de foto viven solo durante el formulario.
- Redis: vínculo del dispositivo (30 días por defecto) y guardia identificado (12 horas) tienen ciclos separados.
- PostgreSQL: credenciales hasheadas, coordenadas de asistencia y referencia relativa de evidencia.
- Filesystem: `backend/uploads/novedades/<uuid>.jpg|png`, excluido de Git. Límite 5 MB, firma JPEG/PNG comprobada, UUID generado por servidor y ningún nombre/ruta del cliente es confiable.
- Multipart: `POST /operacion/dispositivos/<id>/novedades-con-foto`.

## Android SDK

La configuración hereda del Flutter SDK instalado: `compileSdk 36`, `targetSdk 36`, `minSdk 24`; Android Gradle Plugin 9.1.0, Gradle 9.3.1 y Java 17. API 36 corresponde a Android 16 y satisface el requisito indicado por la actividad.

## Matriz de prueba manual

| Caso | Precondición y pasos | Resultado esperado | Resultado obtenido | Evidencia |
|---|---|---|---|---|
| 1. Ubicación concedida | Login Baviera, Diego, 12 h; Registrar; Continuar; conceder. | Coordenadas y asistencia 201. | PENDIENTE EN DISPOSITIVO | Capturas/app y fila DB |
| 2. Ubicación denegada | Revocar permiso; intentar y denegar. | Mensaje, sin asistencia, reintento disponible. | PENDIENTE EN DISPOSITIVO | Video/captura |
| 3. Denegación permanente | Denegar permanentemente; reintentar. | Diálogo Abrir ajustes; vuelve sin asumir concesión. | PENDIENTE EN DISPOSITIVO | Video ajustes |
| 4. Cámara concedida | Nueva novedad; tomar foto; aceptar; enviar. | Preview y novedad multipart relacionada al turno/dispositivo. | PENDIENTE EN DISPOSITIVO | Foto, respuesta y DB |
| 5. Cámara denegada | Denegar o desactivar; continuar sin foto; enviar. | No falla; ofrece ajustes si permanente; novedad 201 sin foto. | PENDIENTE EN DISPOSITIVO | Video/respuesta |
| 6. GPS apagado | Permiso concedido, servicio apagado; Registrar. | Mensaje específico y acción Abrir ubicación. | PENDIENTE EN DISPOSITIVO | Captura |
| 7. Timeout de ubicación | Emulador sin posición o proveedor sin respuesta. | Loading termina, mensaje claro, sin asistencia y reintento disponible. | CUBIERTO AUTOMÁTICAMENTE / PENDIENTE EN DISPOSITIVO | Captura/video |
| 8. Cámara cancelada | Abrir cámara y cancelar. | Conserva formulario y permite enviar sin foto. | CUBIERTO AUTOMÁTICAMENTE / PENDIENTE EN DISPOSITIVO | Captura |
| 9. Cámara permanente | Desactivar permiso en ajustes; Tomar fotografía. | Ofrece Abrir ajustes o continuar sin foto. | CUBIERTO AUTOMÁTICAMENTE / PENDIENTE EN DISPOSITIVO | Video ajustes |
| 10. Navegación operativa | Inicio sin guardia; seleccionar; volver; identificar; cambiar guardia. | La sesión BAVIERA-01 permanece activa. | CUBIERTO AUTOMÁTICAMENTE / PENDIENTE EN DISPOSITIVO | Video de recorrido |

## Prueba en Android físico

1. En el teléfono: Ajustes > Acerca del teléfono; tocar siete veces Número de compilación. En Opciones de desarrollador activar Depuración USB.
2. Conectar por USB, aceptar la huella RSA y ejecutar `flutter devices`.
3. Obtener la IPv4 LAN del PC con `ipconfig`; teléfono y PC deben estar en la misma red. No usar `10.0.2.2`, que solo sirve al emulador.
4. Iniciar Flask escuchando en la LAN, por ejemplo desde `backend`: `..\venv\Scripts\python.exe -m flask run --host=0.0.0.0 --port=5000`.
5. Sin inventar la IP, ejecutar: `flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://<IPV4_DEL_PC>:5000`.
6. Si Windows pregunta, permitir Python/puerto 5000 solo en red privada; no se modifica el firewall automáticamente.
7. Probar `baviera`, Inicio Operativo sin guardia, Diego, 12 h, asistencia, novedad con foto, Cambiar guardia y Humberto. Confirmar que no reaparece el login.

### Ubicación en el emulador Android

El emulador no debe recibir coordenadas falsas desde Pacific Control. Para suministrar una posición de prueba, abrir los tres puntos **Extended Controls** del emulador, entrar en **Location**, seleccionar o escribir una ubicación y pulsar **Set location**. Si el emulador no entrega una posición en 15 segundos, la aplicación cancela el indicador de carga, informa el problema y permite reintentar sin registrar la asistencia.

## Evidencias y video

### Espacios para evidencias reales

- **E1:** portada y login `baviera`.
- **E2:** Inicio Operativo con ED. BAVIERA / BAVIERA-01 y sin guardia.
- **E3:** listas FIJOS y SACA FRANCOS, selector 12/24 y guardia identificado.
- **E4:** ubicación concedida y registro persistido con latitud/longitud.
- **E5:** ubicación denegada, permanente con ajustes, GPS apagado y timeout/reintento.
- **E6:** cámara concedida, preview, repetir/quitar y novedad con foto persistida.
- **E7:** cámara denegada/permanente/cancelada y novedad sin foto persistida.
- **E8:** Cambiar guardia conserva BAVIERA-01; Cerrar dispositivo vuelve a portada.

### Guión breve del video

Grabar en orden: login Baviera; Inicio Operativo; seleccionar Diego y alternar selector 12/24; identificarlo; ubicación concedida y asistencia; denegada, permanente y ajustes; GPS apagado; cámara, preview y envío; denegación y envío sin foto; persistencia backend; cambio a Humberto sin login; cierre del dispositivo y regreso a portada. Insertar E1–E8 tras la prueba física, sin marcar como ejecutado ningún caso pendiente.

Repositorio: https://github.com/MarioBernardo/Pacific-Control

## Limitación honesta

Las suites automatizadas usan abstracciones y no prueban sensores reales. Permisos, GPS, cámara, ajustes y conectividad LAN quedan **PENDIENTES DE VALIDACIÓN EN DISPOSITIVO FÍSICO**.
