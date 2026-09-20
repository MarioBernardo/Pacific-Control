# Semana 14: login operativo y funciones nativas

## Objetivo y alcance

Pacific Control incorpora un acceso operativo por puesto/dispositivo, geolocalización puntual al registrar asistencia y una fotografía opcional al reportar novedades. El acceso administrativo JWT no fue modificado. No existe seguimiento en segundo plano, galería, video ni múltiples fotos.

## Flujo operativo

1. El dispositivo inicia sesión con usuario y contraseña del puesto.
2. El backend valida el hash y emite un token opaco de vinculación, almacenado en `flutter_secure_storage`.
3. Se selecciona un guardia asignado al puesto y un turno `12 HORAS` o `24 HORAS`.
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

La ubicación se pide solo al confirmar `Registrar`; la cámara solo al pulsar `Tomar fotografía`. Ambos flujos muestran primero una explicación con Continuar/Cancelar.

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

## Prueba en Android físico

1. En el teléfono: Ajustes > Acerca del teléfono; tocar siete veces Número de compilación. En Opciones de desarrollador activar Depuración USB.
2. Conectar por USB, aceptar la huella RSA y ejecutar `flutter devices`.
3. Obtener la IPv4 LAN del PC con `ipconfig`; teléfono y PC deben estar en la misma red. No usar `10.0.2.2`, que solo sirve al emulador.
4. Iniciar Flask escuchando en la LAN, por ejemplo desde `backend`: `..\venv\Scripts\python.exe -m flask run --host=0.0.0.0 --port=5000`.
5. Sin inventar la IP, ejecutar: `flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://<IPV4_DEL_PC>:5000`.
6. Si Windows pregunta, permitir Python/puerto 5000 solo en red privada; no se modifica el firewall automáticamente.
7. Probar `baviera`, Diego, 12 h, asistencia, novedad con foto, Cambiar guardia y Humberto. Confirmar que no reaparece el login.

### Ubicación en el emulador Android

El emulador no debe recibir coordenadas falsas desde Pacific Control. Para suministrar una posición de prueba, abrir los tres puntos **Extended Controls** del emulador, entrar en **Location**, seleccionar o escribir una ubicación y pulsar **Set location**. Si el emulador no entrega una posición en 15 segundos, la aplicación cancela el indicador de carga, informa el problema y permite reintentar sin registrar la asistencia.

## Evidencias y video

Grabar en orden: login Baviera; puesto/dispositivo; Diego; selector 12/24; ubicación concedida; denegada; permanente y ajustes; cámara; preview/envío; denegación y envío sin foto; persistencia backend; cambio a Humberto sin login. Adjuntar capturas a esta sección tras la prueba física.

Repositorio: https://github.com/MarioBernardo/Pacific-Control

## Limitación honesta

Las suites automatizadas usan abstracciones y no prueban sensores reales. Permisos, GPS, cámara, ajustes y conectividad LAN quedan **PENDIENTES DE VALIDACIÓN EN DISPOSITIVO FÍSICO**.
