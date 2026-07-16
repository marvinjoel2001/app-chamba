import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/cloudinary_upload_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../request/presentation/screens/request_status_screen.dart';
import '../../../review/presentation/screens/rating_screen.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import '../../domain/usecases/worker_usecases.dart';
import '../state/worker_dependencies.dart';
import 'skills_selection_screen.dart';
import 'work_modalities_screen.dart';
import '../../../history/presentation/screens/job_history_screen.dart';
import 'verification_checkpoint_screen.dart';
import '../../../support/presentation/screens/support_screen.dart';
import '../../../../core/services/mobile_backend_service.dart';

class ProfileMenuScreen extends ConsumerStatefulWidget {
  const ProfileMenuScreen({
    this.uploadWorkerProfilePhotoUseCase,
    this.deleteWorkerProfilePhotoUseCase,
    super.key,
  });

  final UploadWorkerProfilePhotoUseCase? uploadWorkerProfilePhotoUseCase;
  final DeleteWorkerProfilePhotoUseCase? deleteWorkerProfilePhotoUseCase;

  @override
  ConsumerState<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends ConsumerState<ProfileMenuScreen> {
  UploadWorkerProfilePhotoUseCase get _uploadWorkerProfilePhotoUseCase =>
      widget.uploadWorkerProfilePhotoUseCase ??
      WorkerDependencies.uploadWorkerProfilePhoto;
  DeleteWorkerProfilePhotoUseCase get _deleteWorkerProfilePhotoUseCase =>
      widget.deleteWorkerProfilePhotoUseCase ??
      WorkerDependencies.deleteWorkerProfilePhoto;

  final ImagePicker _imagePicker = ImagePicker();
  bool _updatingPhoto = false;
  int _unreadSupportCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadSupportCount();
  }

  Future<void> _loadUnreadSupportCount() async {
    final user = SessionStore.currentUser;
    if (user == null) return;
    try {
      final result = await MobileBackendService.instance.getUserActiveDisputes(user.id);
      final disputes = result['disputes'] as List<dynamic>? ?? [];
      int count = 0;
      for (final d in disputes) {
        count += (d['unreadCount'] as num?)?.toInt() ?? 0;
      }
      if (mounted) {
        setState(() => _unreadSupportCount = count);
      }
    } catch (_) {}
  }

  bool get _isWorker => SessionStore.currentUser?.type == 'worker';

  bool get _isVerified {
    final user = SessionStore.currentUser;
    if (user == null) return false;
    return user.verificationStatus == 'verified' ||
        (user.idPhotoVerified == true && user.facePhotoVerified == true);
  }

  bool get _isVerificationPending {
    final user = SessionStore.currentUser;
    if (user == null) return false;
    return user.verificationStatus == 'pending' ||
        (user.idPhotoVerified == true || user.facePhotoVerified == true) &&
            user.verificationStatus != 'verified';
  }

  void _navigateToVerification() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerificationCheckpointScreen(
          isPending: _isVerificationPending,
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = SessionStore.currentUser;
    if (user == null || _updatingPhoto) {
      return;
    }

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1080,
    );
    if (file == null) {
      return;
    }

    setState(() => _updatingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final uploaded = await CloudinaryUploadService.uploadImageBytes(
        bytes: bytes,
        fileName: file.name,
        folder: 'chamba/profile',
      );
      final result = await _uploadWorkerProfilePhotoUseCase(
        userId: user.id,
        imageUrl: uploaded.secureUrl,
        imagePublicId: uploaded.publicId,
      );
      result.fold(
        onSuccess: (_) {
          SessionStore.currentUser = user.copyWith(
            profilePhotoUrl: uploaded.secureUrl,
          );
          unawaited(SessionStore.persistCurrentUser());
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Foto actualizada')));
        },
        onFailure: (failure) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingPhoto = false);
      }
    }
  }

  Future<void> _removePhoto() async {
    final user = SessionStore.currentUser;
    if (user == null || _updatingPhoto) {
      return;
    }

    setState(() => _updatingPhoto = true);
    final result = await _deleteWorkerProfilePhotoUseCase(userId: user.id);
    result.fold(
      onSuccess: (_) {
        SessionStore.currentUser = user.copyWith(clearProfilePhotoUrl: true);
        unawaited(SessionStore.persistCurrentUser());
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Foto eliminada')));
      },
      onFailure: (failure) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
    if (mounted) {
      setState(() => _updatingPhoto = false);
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Hero(
                tag: 'profile_photo',
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPhotoActionsSheet() async {
    final hasPhoto = SessionStore.currentUser?.profilePhotoUrl != null;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Elegir nueva foto'),
                  subtitle: const Text('Actualizar imagen de perfil'),
                  onTap: _updatingPhoto
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _pickAndUploadPhoto();
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Quitar foto'),
                  subtitle: const Text('Volver al avatar inicial'),
                  onTap: !_updatingPhoto && hasPhoto
                      ? () {
                          Navigator.of(context).pop();
                          _removePhoto();
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text('Quieres cerrar tu sesion actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(authControllerProvider.notifier).logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionStore.currentUser;
    final roleLabel = _isWorker ? 'Trabajador' : 'Empleador';

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadUnreadSupportCount();
              // Refresca los datos de sesión mostrados (foto, verificación).
              if (mounted) setState(() {});
            },
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Mi perfil',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: user?.profilePhotoUrl != null
                                    ? () => _showFullScreenImage(
                                        context, user!.profilePhotoUrl!)
                                    : null,
                                child: Hero(
                                  tag: 'profile_photo',
                                  child: user?.profilePhotoUrl == null
                                      ? CircleAvatar(
                                          radius: 44,
                                          child: Text(
                                            chambaInitial(user?.firstName,
                                                fallback: 'U'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 26,
                                            ),
                                          ),
                                        )
                                      : ClipOval(
                                          child: ChambaNetworkImage(
                                            url: user!.profilePhotoUrl!,
                                            width: 88,
                                            height: 88,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Material(
                                  color: AppTheme.colorPrimary,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: _updatingPhoto
                                        ? null
                                        : _openPhotoActionsSheet,
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: _updatingPhoto
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.edit_outlined,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'Usuario',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? 'Sin correo',
                                style: const TextStyle(
                                  color: AppTheme.colorMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ChambaChip(label: roleLabel, selected: true),
                    ),
                    if (_isWorker) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: _isVerified ? null : _navigateToVerification,
                          child: _isVerificationPending
                              ? ChambaChip(
                                  label: 'Verificación en proceso',
                                  selected: true,
                                  icon: Icons.search,
                                  color: Colors.orange,
                                )
                              : ChambaChip(
                                  label: _isVerified
                                      ? 'Verificado'
                                      : 'Verificar perfil',
                                  selected: _isVerified,
                                  icon: _isVerified
                                      ? Icons.verified
                                      : Icons.warning_amber_rounded,
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionTitle(
                label:
                    _isWorker ? 'Herramientas de trabajo' : 'Gestión de cuenta',
              ),
              if (_isWorker) ...[
                _NavTile(
                  title: 'Historial y pagos',
                  subtitle: 'Revisa trabajos cerrados y montos',
                  icon: Icons.payments_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const JobHistoryScreen(),
                      ),
                    );
                  },
                ),
                _NavTile(
                  title: 'Mis habilidades',
                  subtitle: 'Ajusta los servicios que ofreces',
                  icon: Icons.grid_view_rounded,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SkillsSelectionScreen(),
                      ),
                    );
                  },
                ),
                _NavTile(
                  title: 'Modalidades de trabajo',
                  subtitle: 'Cómo cobras: por trabajo, hora o día',
                  icon: Icons.payments_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WorkModalitiesScreen(),
                      ),
                    );
                  },
                ),
                _NavTile(
                  title: 'Seguimiento activo',
                  subtitle: 'Ve el estado del servicio en curso',
                  icon: Icons.location_searching,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TrackingScreen(),
                      ),
                    );
                  },
                ),
              ] else ...[
                _NavTile(
                  title: 'Mis solicitudes',
                  subtitle: 'Estado actual de tu solicitud publicada',
                  icon: Icons.assignment_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RequestStatusScreen(),
                      ),
                    );
                  },
                ),
                _NavTile(
                  title: 'Historial de trabajos',
                  subtitle: 'Revisa tus trabajos finalizados o cancelados',
                  icon: Icons.history,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const JobHistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
              const _SectionTitle(label: 'Soporte'),
              _NavTile(
                title: 'Soporte',
                subtitle: 'Reporta un problema o contacta con soporte',
                icon: Icons.support_agent,
                badgeCount: _unreadSupportCount,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SupportScreen(),
                    ),
                  );
                },
              ),
              _NavTile(
                title: 'Calificar servicio',
                subtitle: 'Registro rápido de una evaluación',
                icon: Icons.star_rate_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RatingScreen(),
                    ),
                  );
                },
              ),
              _NavTile(
                title: 'Cerrar sesion',
                subtitle: 'Salir de esta cuenta en tu teléfono',
                icon: Icons.logout,
                onTap: _logout,
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: badgeCount > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                )
              : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 10),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.colorMuted,
            ),
      ),
    );
  }
}
