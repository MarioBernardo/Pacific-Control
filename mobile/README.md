# Pacific Control Mobile

La pantalla inicial comprueba el endpoint público `GET /` del backend Flask y
muestra los campos `project`, `status` y `version` devueltos por este.

## Ejecución en el emulador Android

1. Inicia el backend desde `backend` con `python run.py`. Escuchará en el
   puerto `5000` y en todas las interfaces de desarrollo.
2. Desde esta carpeta, instala dependencias con `flutter pub get`.
3. Ejecuta la app en el emulador con:

   ```bash
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
   ```

`10.0.2.2` es la dirección especial que usa el emulador Android para acceder
al `localhost` del equipo que ejecuta el backend. Si se omite el define, la
aplicación usa esa misma URL como valor de desarrollo predeterminado.
