import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/auth/services/auth_session.dart';
import 'package:mobile/main.dart';

class _NoSessionAuthService extends AuthService {
  @override
  Future<AuthSession?> restoreSession() async => null;
}

void main() {
  testWidgets('muestra la aplicacion Pacific Control', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_NoSessionAuthService()),
        ],
        child: const PacificControlApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(PacificControlApp), findsOneWidget);
  });
}
