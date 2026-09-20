import '../../operacion/models/device_session.dart';

enum AccessAccountType { administrative, operational }

class UnifiedAccessResult {
  const UnifiedAccessResult.administrative()
    : accountType = AccessAccountType.administrative,
      device = null;

  const UnifiedAccessResult.operational(this.device)
    : accountType = AccessAccountType.operational;

  final AccessAccountType accountType;
  final DispositivoInfo? device;
}

typedef AdministrativeLogin = Future<void> Function(
  String email,
  String password,
);
typedef OperationalLogin = Future<DispositivoInfo> Function(
  String username,
  String password,
);

/// Selects exactly one existing authentication contract from the identifier.
/// Administrative accounts are emails; operational accounts are usernames.
class UnifiedAccessService {
  const UnifiedAccessService();

  AccessAccountType accountTypeFor(String identifier) =>
      identifier.trim().contains('@')
      ? AccessAccountType.administrative
      : AccessAccountType.operational;

  Future<UnifiedAccessResult> login({
    required String identifier,
    required String password,
    required AdministrativeLogin administrativeLogin,
    required OperationalLogin operationalLogin,
  }) async {
    final normalizedIdentifier = identifier.trim();
    if (accountTypeFor(normalizedIdentifier) ==
        AccessAccountType.administrative) {
      await administrativeLogin(normalizedIdentifier, password);
      return const UnifiedAccessResult.administrative();
    }

    final device = await operationalLogin(normalizedIdentifier, password);
    return UnifiedAccessResult.operational(device);
  }
}
