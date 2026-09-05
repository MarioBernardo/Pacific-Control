# Pacific Control Mobile

La aplicacion Flutter se conecta al backend Flask desde el emulador Android.

## Ejecucion

1. Inicia el backend desde `backend` con `python run.py`.
2. Desde esta carpeta ejecuta `flutter pub get`.
3. Ejecuta:

   ```bash
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
   ```

`10.0.2.2` permite al emulador Android acceder al localhost del equipo host.

## Cliente HTTP autenticado

`lib/services/authenticated_api_client.dart` centraliza solicitudes Bearer JWT.
Recibe un `http.Client` inyectable, no depende de widgets, Riverpod, go_router
ni FlutterSecureStorage. Riverpod le aporta el token actual y un callback para
invalidar la sesion ante 401; 403 conserva la sesion y devuelve un error de
permisos a la capa solicitante.
