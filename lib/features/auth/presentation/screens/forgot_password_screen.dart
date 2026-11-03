import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../google_sign_in_helper.dart';

/// Acceso al backend; se reemplaza en pruebas.
class PasswordRecoveryApi {
  const PasswordRecoveryApi();

  Future<Map<String, dynamic>> start(String idToken) =>
      MobileBackendService.instance.startGooglePasswordReset(idToken: idToken);

  Future<Map<String, dynamic>> complete(
    String resetToken,
    String newPassword,
  ) =>
      MobileBackendService.instance.completeGooglePasswordReset(
        resetToken: resetToken,
        newPassword: newPassword,
      );
}

/// "Olvidé mi contraseña": la persona entra con la cuenta de Google del mismo
/// correo con el que se registró y crea una contraseña nueva. Al guardar,
/// cierra con la sesión nueva (`user` y `token`) para que el login la use.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    this.api = const PasswordRecoveryApi(),
    this.requestIdToken = requestGoogleIdToken,
    super.key,
  });

  final PasswordRecoveryApi api;
  final Future<String?> Function() requestIdToken;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const int _minLength = 8;

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _resetToken;
  String _email = '';
  String _firstName = '';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _messageFor(Object error) {
    if (error is ApiException || error is NetworkException) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return googleSignInErrorMessage(error);
  }

  Future<void> _verifyWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final idToken = await widget.requestIdToken();
      if (idToken == null) return; // Cerró el selector de cuentas.
      final data = await widget.api.start(idToken);
      if (!mounted) return;
      setState(() {
        _resetToken = data['resetToken']?.toString();
        _email = data['email']?.toString() ?? '';
        _firstName = data['firstName']?.toString() ?? '';
      });
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final token = _resetToken;
    if (token == null || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session =
          await widget.api.complete(token, _passwordController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (error) {
      if (!mounted) return;
      final message = _messageFor(error);
      setState(() {
        _error = message;
        // Si el permiso venció, se vuelve a pedir Google.
        if (message.contains('venció')) _resetToken = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Recuperar contraseña'),
      ),
      body: ChambaBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: _resetToken == null
                      ? _buildVerifyStep(textTheme)
                      : _buildPasswordStep(textTheme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyStep(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset_rounded,
            size: 56, color: AppTheme.colorPrimary),
        const SizedBox(height: 14),
        Text(
          'Recupera tu cuenta con Google',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(color: AppTheme.colorText),
        ),
        const SizedBox(height: 8),
        Text(
          'Entra con la cuenta de Google del mismo correo con el que te '
          'registraste en Chamba. Así comprobamos que la cuenta es tuya y '
          'puedes crear una contraseña nueva.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppTheme.colorMuted),
        ),
        const SizedBox(height: 22),
        ChambaPrimaryButton(
          key: const Key('forgot-google'),
          label: _busy ? 'Verificando...' : 'Continuar con Google',
          icon: Icons.verified_user_outlined,
          onPressed: _busy ? null : _verifyWithGoogle,
        ),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: 14),
        Text(
          'Si tu correo no es una cuenta de Google, escríbenos a soporte para '
          'recuperar tu cuenta.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppTheme.colorMuted),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(TextTheme textTheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _firstName.isEmpty ? 'Crea tu contraseña' : 'Hola, $_firstName',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(color: AppTheme.colorText),
          ),
          const SizedBox(height: 6),
          Text(
            'Crea una contraseña nueva para $_email.',
            key: const Key('forgot-email'),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppTheme.colorMuted),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('forgot-password'),
            controller: _passwordController,
            obscureText: _obscure,
            enabled: !_busy,
            style: const TextStyle(color: AppTheme.colorText),
            decoration: AppTheme.glassInputDecoration(
              labelText: 'Contraseña nueva',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.colorMuted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (value) => (value ?? '').trim().length < _minLength
                ? 'Usa al menos $_minLength caracteres'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('forgot-confirm'),
            controller: _confirmController,
            obscureText: _obscure,
            enabled: !_busy,
            style: const TextStyle(color: AppTheme.colorText),
            decoration: AppTheme.glassInputDecoration(
              labelText: 'Repite la contraseña',
              icon: Icons.lock_outline_rounded,
            ),
            validator: (value) =>
                (value ?? '').trim() != _passwordController.text.trim()
                    ? 'Las contraseñas no coinciden'
                    : null,
          ),
          const SizedBox(height: 10),
          Text(
            'Por seguridad cerraremos tu sesión en otros teléfonos.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppTheme.colorMuted),
          ),
          const SizedBox(height: 18),
          ChambaPrimaryButton(
            key: const Key('forgot-save'),
            label: _busy ? 'Guardando...' : 'Guardar y entrar',
            onPressed: _busy ? null : _save,
          ),
          if (_error != null) _ErrorText(_error!),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          message,
          key: const Key('forgot-error'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.colorError,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
