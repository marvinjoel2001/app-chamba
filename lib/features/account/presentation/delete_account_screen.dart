import 'package:flutter/material.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/session/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_labels.dart';
import '../domain/account_deletion.dart';
import 'pending_deletion_banner.dart';

/// Eliminar la cuenta con varias barreras contra errores:
/// 1. La pantalla está al fondo de Perfil → Configuración de la cuenta.
/// 2. Explica qué se pierde (billetera, historial, documentos).
/// 3. Hay que escribir el correo exacto de la cuenta.
/// 4. Se confirma otra vez en un diálogo.
/// 5. El borrado real ocurre a los 30 días y se puede cancelar antes.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({this.api = const AccountDeletionApi(), super.key});

  final AccountDeletionApi api;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _emailController = TextEditingController();
  AccountDeletionStatus? _scheduled;
  bool _sending = false, _cancelling = false;
  String? _error;

  String get _accountEmail => SessionStore.currentUser?.email ?? '';
  bool get _isWorker => SessionStore.currentUser?.type == 'worker';
  bool get _matches =>
      deletionEmailMatches(_emailController.text, _accountEmail);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndRequest() async {
    if (!_matches || _sending) return;
    final estimated = DateTime.now().add(const Duration(days: 30));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppTheme.colorError, size: 36),
        title: const Text('¿Programar la eliminación?'),
        content: Text(
          'Tu cuenta se eliminará el ${longDateLabel(estimated)}. '
          'Hasta entonces puedes cancelarlo desde tu perfil. '
          'Después no se podrá recuperar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, conservar mi cuenta'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.colorError),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final status = await widget.api.request(_emailController.text);
      if (!mounted) return;
      setState(() => _scheduled = status);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await widget.api.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listo, tu cuenta ya no se eliminará.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_messageFor(error))));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is NetworkException) return error.message;
    return 'No pudimos completar la acción. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = _scheduled;
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: AppTheme.colorBackground,
        appBar: AppBar(title: const Text('Eliminar cuenta')),
        body: SafeArea(
          child: scheduled != null && scheduled.pending
              ? _buildScheduled(scheduled)
              : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildScheduled(AccountDeletionStatus status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.event_busy_rounded,
              size: 56, color: AppTheme.colorError),
          const SizedBox(height: 16),
          const Text(
            'Eliminación programada',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.colorText),
          ),
          const SizedBox(height: 8),
          const Text(
            'Te avisamos en tu perfil mientras tanto. Si cambias de opinión, '
            'cancélalo antes de la fecha.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.colorMuted,
                height: 1.5,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          PendingDeletionBanner(
              status: status, onCancel: _cancel, cancelling: _cancelling),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Volver al perfil'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final loses = <(IconData, String)>[
      (Icons.person_off_rounded, 'Tu nombre, foto, teléfono y correo.'),
      if (_isWorker) ...[
        (
          Icons.account_balance_wallet_rounded,
          'Tu billetera: ganancias registradas, historial y estadísticas.'
        ),
        (
          Icons.badge_rounded,
          'Tu verificación de identidad y fotos de documentos.'
        ),
        (Icons.star_rounded, 'Tus calificaciones, habilidades y portafolio.'),
      ] else
        (Icons.receipt_long_rounded, 'Tu historial de solicitudes y trabajos.'),
      (Icons.lock_rounded, 'Tu acceso: no podrás volver a iniciar sesión.'),
    ];

    // Formulario corto: todo construido de una vez (sin ListView perezoso).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.colorErrorSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.colorError),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Esta acción elimina tu cuenta de Chamba. Léelo con calma antes de continuar.',
                    style: TextStyle(
                      color: AppTheme.colorText,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _Heading('Qué se elimina'),
          ...loses.map((item) => _Bullet(icon: item.$1, text: item.$2)),
          const SizedBox(height: 6),
          const Text(
            'Los trabajos y chats que tuviste con otras personas se conservan para ellas, '
            'pero aparecerás como "Usuario eliminado".',
            style: TextStyle(
                color: AppTheme.colorMuted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 22),
          const _Heading('Cómo funciona'),
          const _Bullet(
            icon: Icons.hourglass_bottom_rounded,
            text:
                'Tu cuenta se elimina recién en 30 días. Mientras tanto puedes seguir usándola.',
          ),
          const _Bullet(
            icon: Icons.restore_rounded,
            text:
                'Puedes cancelar la eliminación desde tu perfil en cualquier momento antes de esa fecha.',
          ),
          const _Bullet(
            icon: Icons.work_off_rounded,
            text:
                'Si tienes un trabajo o una solicitud en curso, primero debes terminarlo o cancelarlo.',
          ),
          const SizedBox(height: 26),
          const _Heading('Confirma con tu correo'),
          Text(
            'Escribe el correo de tu cuenta (${maskEmail(_accountEmail)}) para confirmar que eres tú.',
            style: const TextStyle(
                color: AppTheme.colorMuted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('delete-account-email'),
            controller: _emailController,
            enabled: !_sending,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'tu correo',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              errorText: _error,
              errorMaxLines: 3,
              suffixIcon: _matches
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppTheme.colorSuccess)
                  : null,
            ),
            onSubmitted: (_) => _confirmAndRequest(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const Key('delete-account-submit'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorError,
                disabledBackgroundColor: const Color(0xFFE9E3EE),
              ),
              onPressed: _matches && !_sending ? _confirmAndRequest : null,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_forever_rounded),
              label: Text(
                  _sending ? 'Programando…' : 'Eliminar mi cuenta en 30 días'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: const Text('No, conservar mi cuenta'),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.colorText,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppTheme.colorMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppTheme.colorText,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}
