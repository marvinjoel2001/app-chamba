import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/cloudinary_upload_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../onboarding/presentation/screens/role_selection_screen.dart';
import '../../../offers/presentation/screens/offers_screen.dart';
import '../../../request/presentation/screens/request_status_screen.dart';
import '../../../request/presentation/screens/empty_requests_screen.dart';
import '../../../review/presentation/screens/rating_screen.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import 'radar_screen.dart';
import 'skills_selection_screen.dart';
import 'worker_history_screen.dart';

class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _updatingPhoto = false;

  bool get _isWorker => SessionStore.currentUser?.type == 'worker';

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
      final response = await MobileBackendService.uploadProfilePhoto(
        userId: user.id,
        imageUrl: uploaded.secureUrl,
        imagePublicId: uploaded.publicId,
      );

      final updated = response['user'];
      if (updated is Map<String, dynamic>) {
        SessionStore.currentUser = SessionUser.fromJson(updated);
        unawaited(SessionStore.persistCurrentUser());
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto actualizada')));
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
    try {
      final response = await MobileBackendService.deleteProfilePhoto(
        userId: user.id,
      );
      final updated = response['user'];
      if (updated is Map<String, dynamic>) {
        SessionStore.currentUser = SessionUser.fromJson(updated);
      } else {
        SessionStore.currentUser = user.copyWith(clearProfilePhotoUrl: true);
      }
      unawaited(SessionStore.persistCurrentUser());

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto eliminada')));
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

    await AuthService().logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
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
          child: ListView(
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
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundImage: user?.profilePhotoUrl == null
                                  ? null
                                  : NetworkImage(user!.profilePhotoUrl!),
                              child: user?.profilePhotoUrl == null
                                  ? Text(
                                      (user?.firstName ?? 'U').substring(0, 1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 22,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Material(
                                color: AppTheme.colorPrimary,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  onPressed: _updatingPhoto
                                      ? null
                                      : _openPhotoActionsSheet,
                                  icon: _updatingPhoto
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
                                          size: 18,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'Usuario',
                                style: Theme.of(context).textTheme.headlineSmall
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionTitle(
                label: _isWorker
                    ? 'Herramientas de trabajo'
                    : 'Gestión de cuenta',
              ),
              if (_isWorker) ...[
                _NavTile(
                  title: 'Historial y pagos',
                  subtitle: 'Revisa trabajos cerrados y montos',
                  icon: Icons.payments_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WorkerHistoryScreen(),
                      ),
                    );
                  },
                ),
                _NavTile(
                  title: 'Radar y ubicación',
                  subtitle: 'Activa disponibilidad y actualiza tu posición',
                  icon: Icons.radar,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RadarScreen(),
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
                  title: 'Ofertas recibidas',
                  subtitle: 'Compara propuestas y acepta la mejor',
                  icon: Icons.local_offer_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OffersScreen(),
                      ),
                    );
                  },
                ),
                _NavTile(
                  title: 'Mensajes',
                  subtitle: 'Habla con trabajadores y clientes',
                  icon: Icons.chat_bubble_outline,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MessagesScreen(),
                      ),
                    );
                  },
                ),
                _NavTile(
                  title: 'Mapa y categorías',
                  subtitle: 'Explora servicios y zonas cercanas',
                  icon: Icons.map_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ExploreScreen(role: 'client'),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
              const _SectionTitle(label: 'Soporte'),
              _NavTile(
                title: 'Pantalla sin solicitudes',
                subtitle: 'Vista alternativa cuando no hay resultados',
                icon: Icons.inbox_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EmptyRequestsScreen(),
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
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

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
          trailing: const Icon(Icons.chevron_right),
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
