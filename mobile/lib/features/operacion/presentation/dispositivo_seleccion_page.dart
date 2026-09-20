import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../models/device_session.dart';
import '../services/operacion_service.dart';

String? operationalUsernameValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Ingresa el usuario.';
  }
  return null;
}

/// Lists available devices so the user can select one to operate.
class DispositivoSeleccionPage extends ConsumerStatefulWidget {
  const DispositivoSeleccionPage({super.key});

  @override
  ConsumerState<DispositivoSeleccionPage> createState() =>
      _DispositivoSeleccionPageState();
}

class _DispositivoSeleccionPageState
    extends ConsumerState<DispositivoSeleccionPage> {
  final _formKey = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    final id = await ref.read(operacionServiceProvider).restoreDeviceSession();
    if (!mounted) return;
    if (id != null) {
      context.go('/operacion/$id');
      return;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final device = await ref
          .read(operacionServiceProvider)
          .login(_usuario.text.trim(), _password.text);
      if (mounted) context.go('/operacion/${device.idDispositivo}');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso operativo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.phone_android,
              size: 64,
              color: AppColors.darkBlue,
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('operational_username'),
              controller: _usuario,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                hintText: 'baviera',
              ),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              validator: operationalUsernameValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('operational_password'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              validator: (value) => value == null || value.isEmpty
                  ? 'Ingresa tu contraseña.'
                  : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _activate,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('INICIAR SESIÓN'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Volver al acceso administrativo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _DispositivoCard extends StatelessWidget {
  const _DispositivoCard({required this.dispositivo, required this.onTap});

  final DispositivoInfo dispositivo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.orangeSurface,
          child: const Icon(Icons.phone_android, color: AppColors.darkBlue),
        ),
        title: Text(
          dispositivo.codigoDispositivo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          dispositivo.puesto?.nombrePuesto ?? 'Puesto #${dispositivo.idPuesto}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ignore: unused_element
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'No se pudieron cargar los dispositivos.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
