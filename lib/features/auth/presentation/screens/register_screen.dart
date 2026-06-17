import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/services/app_permissions_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../onboarding/presentation/screens/required_permissions_screen.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import '../../../worker/presentation/state/worker_dependencies.dart';
import '../../../worker/presentation/screens/skills_selection_screen.dart';
import '../controllers/auth_controller.dart';
import 'terms_and_conditions_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ciController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'client';
  String _countryCode = '+591';
  bool _acceptedTerms = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ciController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthenticated() async {
    final user = SessionStore.currentUser;
    if (user == null || !mounted) {
      return;
    }

    Widget nextScreen = MainShellScreen(
      role: SessionStore.currentUser?.type ?? _selectedRole,
    );

    if (user.type == 'worker') {
      final result = await WorkerDependencies.getWorkerSkills(
        workerUserId: user.id,
      );
      result.fold(
        onSuccess: (skills) {
          if (skills.isEmpty) {
            nextScreen = const SkillsSelectionScreen(
              forceToHomeAfterSave: true,
            );
          }
        },
        onFailure: (_) {},
      );
    }

    if (!mounted) return;

    RealtimeService.instance.connect(userId: user.id);

    final allPermissionsGranted =
        await AppPermissionsService.areAllRequiredPermissionsGranted(user.type);
    if (!mounted) return;

    final destination = allPermissionsGranted
        ? nextScreen
        : RequiredPermissionsScreen(role: user.type, nextScreen: nextScreen);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage!.isNotEmpty &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        _handleAuthenticated();
      }
    });

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GlassCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _selectedRole == 'worker'
                              ? 'Registro trabajador'
                              : 'Registro contratante',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChambaChip(
                                label: 'Quiero contratar',
                                selected: _selectedRole == 'client',
                                onTap: authState.isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedRole = 'client';
                                        });
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChambaChip(
                                label: 'Quiero trabajar',
                                selected: _selectedRole == 'worker',
                                onTap: authState.isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedRole = 'worker';
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _firstNameController,
                          style: const TextStyle(color: AppTheme.colorText),
                          decoration: AppTheme.glassInputDecoration(
                            labelText: 'Nombre',
                            icon: Icons.person_outline,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          style: const TextStyle(color: AppTheme.colorText),
                          decoration: AppTheme.glassInputDecoration(
                            labelText: 'Apellido (opcional)',
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: AppTheme.colorText),
                          decoration: AppTheme.glassInputDecoration(
                            labelText: 'Correo',
                            icon: Icons.alternate_email,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu correo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        IntlPhoneField(
                          controller: _phoneController,
                          initialCountryCode: 'BO',
                          onChanged: (phone) {
                            _countryCode = phone.countryCode;
                          },
                          style: const TextStyle(color: AppTheme.colorText),
                          decoration: AppTheme.glassInputDecoration(
                            labelText: 'Teléfono (opcional)',
                            icon: Icons.phone_android_outlined,
                          ),
                        ),
                        if (_selectedRole == 'worker') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _ciController,
                            style: const TextStyle(color: AppTheme.colorText),
                            decoration: AppTheme.glassInputDecoration(
                              labelText: 'Número de Carnet (CI)',
                              icon: Icons.badge_outlined,
                            ),
                            validator: (value) {
                              if (_selectedRole == 'worker' && (value == null || value.trim().isEmpty)) {
                                return 'Ingresa tu número de carnet';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: AppTheme.colorText),
                          decoration: AppTheme.glassInputDecoration(
                            labelText: 'Contraseña',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppTheme.colorMuted,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.length < 4) {
                              return 'Mínimo 4 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: authState.isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _acceptedTerms = value ?? false;
                                      });
                                    },
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'Acepto los Términos y Condiciones de Chamba',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.colorText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: authState.isLoading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const TermsAndConditionsScreen(),
                                      ),
                                    );
                                  },
                            icon: const Icon(
                              Icons.description_outlined,
                              size: 18,
                            ),
                            label: const Text('Ver Términos y Condiciones'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ChambaPrimaryButton(
                          label: authState.isLoading
                              ? 'Registrando...'
                              : 'Crear cuenta',
                          onPressed: authState.isLoading || !_acceptedTerms
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }

                                  await ref
                                      .read(authControllerProvider.notifier)
                                      .register(
                                        role: _selectedRole,
                                        email: _emailController.text,
                                        phone: _phoneController.text,
                                        countryCode: _countryCode,
                                        ciNumber: _selectedRole == 'worker' ? _ciController.text : null,
                                        firstName: _firstNameController.text,
                                        lastName: _lastNameController.text,
                                        password: _passwordController.text,
                                      );
                                },
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Ya tengo cuenta'),
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
