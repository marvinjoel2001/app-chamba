import 'package:flutter/material.dart';

import '../../../core/session/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/screens/terms_and_conditions_screen.dart';
import '../domain/account_deletion.dart';
import 'delete_account_screen.dart';
import 'pending_deletion_banner.dart';

/// Perfil → Configuración de la cuenta. "Eliminar mi cuenta" queda al final,
/// como enlace discreto, para que nadie llegue a él por accidente.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen(
      {this.api = const AccountDeletionApi(), super.key});

  final AccountDeletionApi api;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  AccountDeletionStatus _status = const AccountDeletionStatus.none();
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await widget.api.status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Sin red el aviso simplemente no aparece; el servidor sigue siendo la
      // fuente de verdad y se reintenta al volver a entrar.
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      final status = await widget.api.cancel();
      if (!mounted) return;
      setState(() => _status = status);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listo, tu cuenta ya no se eliminará.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No pudimos cancelar. Revisa tu conexión e inténtalo de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _openDelete() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => DeleteAccountScreen(api: widget.api)),
    );
    if (mounted) _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionStore.currentUser;
    final rows = <(IconData, String, String)>[
      (Icons.person_rounded, 'Nombre', user?.fullName ?? '—'),
      (Icons.alternate_email_rounded, 'Correo', user?.email ?? '—'),
      if ((user?.phone ?? '').isNotEmpty)
        (Icons.phone_rounded, 'Teléfono', user!.phone!),
      (
        Icons.badge_rounded,
        'Tipo de cuenta',
        user?.type == 'worker' ? 'Trabajador' : 'Cliente',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      appBar: AppBar(title: const Text('Configuración de la cuenta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_status.pending) ...[
              PendingDeletionBanner(
                  status: _status, onCancel: _cancel, cancelling: _cancelling),
              const SizedBox(height: 16),
            ],
            _Card(
              children: [
                for (final (icon, label, value) in rows)
                  ListTile(
                    leading: Icon(icon, color: AppTheme.colorPrimary),
                    title: Text(label,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.colorMuted)),
                    subtitle: Text(value,
                        style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.colorText,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_rounded,
                      color: AppTheme.colorPrimary),
                  title: const Text('Términos y condiciones'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const TermsAndConditionsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            // Discreto a propósito: texto pequeño al final, sin ícono llamativo.
            if (!_status.pending)
              Center(
                child: TextButton(
                  key: const Key('open-delete-account'),
                  onPressed: _openDelete,
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.colorMuted),
                  child: const Text(
                    'Eliminar mi cuenta',
                    style: TextStyle(
                        fontSize: 13, decoration: TextDecoration.underline),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  // Material (no Container con color) para que el toque de los ListTile se vea.
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.colorGlassBorder),
        ),
        child: Column(children: children),
      );
}
