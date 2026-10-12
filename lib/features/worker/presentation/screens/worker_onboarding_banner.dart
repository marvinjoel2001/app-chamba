import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../state/worker_dependencies.dart';
import 'skills_selection_screen.dart';
import 'work_modalities_screen.dart';
import 'verification_checkpoint_screen.dart';

/// Account access stays open; these steps are completed inside the app.
class WorkerOnboardingBanner extends StatefulWidget {
  const WorkerOnboardingBanner({super.key});

  @override
  State<WorkerOnboardingBanner> createState() => _WorkerOnboardingBannerState();
}

class _WorkerOnboardingBannerState extends State<WorkerOnboardingBanner> {
  bool? _hasSkills;
  bool? _hasModalities;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final user = SessionStore.currentUser;
    if (user == null || !user.needsWorkerVerification) return;
    final skills =
        await WorkerDependencies.getWorkerSkills(workerUserId: user.id);
    final modalities =
        await WorkerDependencies.getWorkerModalities(workerUserId: user.id);
    if (!mounted) return;
    setState(() {
      skills.fold(
          onSuccess: (value) => _hasSkills = value.isNotEmpty,
          onFailure: (_) {});
      modalities.fold(
          onSuccess: (value) => _hasModalities = value.modalities.isNotEmpty,
          onFailure: (_) {});
    });
  }

  Future<void> _openSteps() async {
    final user = SessionStore.currentUser;
    if (user == null) return;
    final submitted = user.verificationStatus == 'pending' &&
        (user.idPhotoUrl?.isNotEmpty ?? false) &&
        (user.facePhotoUrl?.isNotEmpty ?? false);
    final destination = await showModalBottomSheet<Widget>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu cuenta ya está lista',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                  'Puedes explorar Chamba y completar tu perfil. Para ponerte disponible y aceptar trabajos, verifica tu identidad.'),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(_hasSkills == true
                    ? Icons.check_circle
                    : Icons.handyman_outlined),
                title: const Text('Elige tus oficios'),
                subtitle: Text(_hasSkills == true
                    ? 'Completado · puedes editarlo'
                    : 'Cuéntanos qué trabajos puedes hacer'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.pop(context, const SkillsSelectionScreen()),
              ),
              ListTile(
                leading: Icon(_hasModalities == true
                    ? Icons.check_circle
                    : Icons.payments_outlined),
                title: const Text('Completa tus modalidades y tarifas'),
                subtitle: Text(_hasModalities == true
                    ? 'Completado · puedes editarlo'
                    : 'Elige cómo quieres cobrar'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.pop(context, const WorkModalitiesScreen()),
              ),
              ListTile(
                leading: Icon(
                    submitted ? Icons.hourglass_top : Icons.badge_outlined),
                title: Text(submitted
                    ? 'Identidad en revisión'
                    : 'Verifica tu identidad'),
                subtitle: Text(submitted
                    ? 'Nuestro equipo revisará tus documentos'
                    : 'Envía una foto de tu carnet y una de tu rostro'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context,
                    VerificationCheckpointScreen(isPending: submitted)),
              ),
              const SizedBox(height: 12),
              const Text(
                  'Nuestro equipo te acompañará para continuar el proceso.'),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Seguir explorando'))),
            ],
          ),
        ),
      ),
    );
    if (!mounted || destination == null) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => destination));
    if (mounted) {
      setState(() {});
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionStore.currentUser;
    if (user == null || !user.needsWorkerVerification) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      bottom: false,
      child: Material(
        color: AppTheme.colorBackground,
        child: ListTile(
          leading: const Icon(Icons.verified_user_outlined,
              color: AppTheme.colorPrimary),
          title: const Text('Verificación pendiente',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(user.verificationStatus == 'pending'
              ? 'Identidad en revisión. Puedes seguir explorando.'
              : 'Explora la app y completa tu perfil a tu ritmo.'),
          trailing:
              TextButton(onPressed: _openSteps, child: const Text('Ver pasos')),
        ),
      ),
    );
  }
}
