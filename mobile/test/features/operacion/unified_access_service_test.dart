import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/services/unified_access_service.dart';
import 'package:mobile/features/operacion/models/device_session.dart';

const _device = DispositivoInfo(
  idDispositivo: 7,
  codigoDispositivo: 'BAVIERA-01',
  estado: 'ACTIVO',
  idPuesto: 1,
);

void main() {
  const service = UnifiedAccessService();

  test('cuenta administrativa usa solo autenticacion administrativa', () async {
    var administrativeCalls = 0;
    var operationalCalls = 0;
    final result = await service.login(
      identifier: ' admin@pacific-control.com ',
      password: 'secret',
      administrativeLogin: (identifier, _) async {
        administrativeCalls++;
        expect(identifier, 'admin@pacific-control.com');
      },
      operationalLogin: (_, _) async {
        operationalCalls++;
        return _device;
      },
    );
    expect(result.accountType, AccessAccountType.administrative);
    expect(result.device, isNull);
    expect(administrativeCalls, 1);
    expect(operationalCalls, 0);
  });

  for (final username in ['baviera', 'century', 'grandvictoria', 'vertice']) {
    test('$username usa solo autenticacion operativa', () async {
      var administrativeCalls = 0;
      var operationalCalls = 0;
      final result = await service.login(
        identifier: ' $username ',
        password: 'secret',
        administrativeLogin: (_, _) async => administrativeCalls++,
        operationalLogin: (identifier, _) async {
          operationalCalls++;
          expect(identifier, username);
          return _device;
        },
      );
      expect(result.accountType, AccessAccountType.operational);
      expect(result.device, same(_device));
      expect(administrativeCalls, 0);
      expect(operationalCalls, 1);
    });
  }

  test('error administrativo no intenta autenticacion operativa', () async {
    var operationalCalls = 0;
    await expectLater(
      service.login(
        identifier: 'admin@pacific-control.com',
        password: 'bad',
        administrativeLogin: (_, _) async => throw StateError('invalid'),
        operationalLogin: (_, _) async {
          operationalCalls++;
          return _device;
        },
      ),
      throwsStateError,
    );
    expect(operationalCalls, 0);
  });

  test('error operativo no intenta autenticacion administrativa', () async {
    var administrativeCalls = 0;
    await expectLater(
      service.login(
        identifier: 'baviera',
        password: 'bad',
        administrativeLogin: (_, _) async => administrativeCalls++,
        operationalLogin: (_, _) async => throw StateError('invalid'),
      ),
      throwsStateError,
    );
    expect(administrativeCalls, 0);
  });
}
