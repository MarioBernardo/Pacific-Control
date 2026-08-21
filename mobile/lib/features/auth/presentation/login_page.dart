import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/brand_logo.dart';
import '../../../widgets/primary_button.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });

  final AuthService authService;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await widget.authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        widget.onAuthenticated(session);
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          'Gestión y control del personal de seguridad',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),

                        const SizedBox(height: 32),

                        AppTextField(
                          controller: _emailController,
                          label: 'Usuario',
                          hint: 'correo@empresa.com',
                          prefixIcon: Icons.person_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu correo institucional.';
                            }

                            if (!value.contains('@')) {
                              return 'Ingresa un correo válido.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        AppTextField(
                          controller: _passwordController,
                          label: 'Contraseña',
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu contraseña.';
                            }

                            return null;
                          },
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
                              style: TextStyle(
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        PrimaryButton(
                          label: 'INICIAR SESIÓN',
                          onPressed: _submit,
                          loading: _isLoading,
                        ),

                        const SizedBox(height: 18),

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