/// Configuración inyectada en tiempo de compilación con `--dart-define`.
///
/// En el emulador Android, 10.0.2.2 representa el localhost del equipo host.
abstract final class AppEnvironment {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
}
