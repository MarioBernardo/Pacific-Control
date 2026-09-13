import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    if (session == null) return const SizedBox.shrink();

    final position = session.employee.position.trim().toUpperCase();
    final isAdmin = position == 'ADMINISTRADOR';
    final isSupervisor = position == 'SUPERVISOR';
    final canManage = isAdmin || isSupervisor;

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
            // Header
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

            // Session card
            _StatusCard(session: session),
            const SizedBox(height: 24),

            // ── Operación ──────────────────────────────────
            Text('Operación', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.push('/operacion'),
              icon: const Icon(Icons.security),
              label: const Text('Operación de dispositivo'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/asistencias'),
              icon: const Icon(Icons.fact_check),
              label: const Text('Asistencias'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/novedades'),
              icon: const Icon(Icons.add_alert),
              label: const Text('Novedades'),
            ),

            // ── Gestión (Admin/Supervisor) ─────────────────
            if (canManage) ...[
              const SizedBox(height: 24),
              Text('Gestión', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => context.push('/puestos'),
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Puestos'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/dispositivos'),
                icon: const Icon(Icons.phone_android_outlined),
                label: const Text('Dispositivos'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/turnos'),
                icon: const Icon(Icons.schedule),
                label: const Text('Turnos'),
              ),
            ],

            // ── Administración (solo Admin) ─────────────────
            if (isAdmin) ...[
              const SizedBox(height: 24),
              Text(
                'Administración',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => context.push('/empleados'),
                icon: const Icon(Icons.people_outlined),
                label: const Text('Empleados'),
              ),
            ],

            // ── Diagnóstico ─────────────────────────────────
            const SizedBox(height: 24),
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

class _BackendDiagnosticsPage extends StatelessWidget {
  const _BackendDiagnosticsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico de conexión')),
      body: Center(child: BackendStatusPage()),
    );
  }
}
