import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/brand_logo.dart';
import '../../backend_status/backend_status_page.dart';
import '../auth_provider.dart';
import '../services/auth_session.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    if (session == null) {
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PACIFIC CONTROL',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                const BrandLogo(height: 58),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${session.employee.firstName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(session.employee.position),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _StatusCard(session: session),
            const SizedBox(height: 20),
            Text('Próximamente', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            const _FutureModulesCard(),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _BackendDiagnosticsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Diagnóstico de conexión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, color: AppColors.orange),
              SizedBox(width: 8),
              Text(
                'Sesión activa',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            session.employee.fullName,
            style: const TextStyle(color: AppColors.white, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            session.employee.email,
            style: const TextStyle(color: AppColors.lightBlueText),
          ),
        ],
      ),
    );
  }
}

class _FutureModulesCard extends StatelessWidget {
  const _FutureModulesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.orangeSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.dashboard_outlined,
                  color: AppColors.darkBlue),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Módulos operativos'),
                  SizedBox(height: 4),
                  Text(
                    'Esta sección se habilitará en próximas etapas.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackendDiagnosticsPage extends StatelessWidget {
  const _BackendDiagnosticsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Diagnóstico de conexión')),
      body: Center(child: BackendStatusPage()),
    );
  }
}
