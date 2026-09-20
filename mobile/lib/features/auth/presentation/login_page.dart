import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../services/authenticated_api_client.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/brand_logo.dart';
import '../../../widgets/primary_button.dart';
import '../auth_provider.dart';
import '../services/auth_service.dart';
import '../services/unified_access_service.dart';
import '../../operacion/services/operacion_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isRestoringOperationalSession = true;
  final _unifiedAccessService = const UnifiedAccessService();

  @override
  void initState() {
    super.initState();
    _restoreOperationalSession();
  }

  Future<void> _restoreOperationalSession() async {
    int? deviceId;
    try {
      deviceId = await ref
          .read(operacionServiceProvider)
          .restoreDeviceSession();
    } catch (_) {
      deviceId = null;
    } finally {
      if (mounted) {
        setState(() => _isRestoringOperationalSession = false);
      }
    }
    if (mounted && deviceId != null) {
      context.go('/operacion/$deviceId');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _unifiedAccessService.login(
        identifier: _usernameController.text,
        password: _passwordController.text,
        administrativeLogin: (email, password) => ref
            .read(authControllerProvider.notifier)
            .login(email: email, password: password),
        operationalLogin: (username, password) async {
          final device = await ref
              .read(operacionServiceProvider)
              .login(username, password);
          await ref.read(authControllerProvider.notifier).logout();
          return device;
        },
      );
      if (mounted && result.accountType == AccessAccountType.operational) {
        context.go('/operacion/${result.device!.idDispositivo}');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'No fue posible iniciar sesión. Inténtalo nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoringOperationalSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: SizedBox(
                            width: 280,
                            height: 180,
                            child: BrandLogo(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'PACIFIC CONTROL',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gestion y control del personal de seguridad',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        AppTextField(
                          key: const Key('unified_username'),
                          controller: _usernameController,
                          label: 'Usuario',
                          hint: 'Ingresa tu usuario',
                          prefixIcon: Icons.person_outline,
                          keyboardType: TextInputType.text,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa el usuario.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          key: const Key('unified_password'),
                          controller: _passwordController,
                          label: 'Contrasena',
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar contrasena'
                                : 'Ocultar contrasena',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Ingresa tu contrasena.'
                              : null,
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: 'INICIAR SESION',
                          onPressed: _submit,
                          loading: _isLoading,
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 17,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 7),
                            Text('Acceso seguro al sistema'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
