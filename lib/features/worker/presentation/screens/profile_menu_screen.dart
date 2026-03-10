import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../request/presentation/screens/empty_requests_screen.dart';
import '../../../review/presentation/screens/rating_screen.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import 'radar_screen.dart';
import 'skills_selection_screen.dart';

class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _updatingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    final user = SessionStore.currentUser;
    if (user == null || _updatingPhoto) {
      return;
    }

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (file == null) {
      return;
    }

    setState(() => _updatingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final imageBase64 =
          'data:${_resolveMimeType(file.path)};base64,${base64Encode(bytes)}';
      final response = await MobileBackendService.uploadProfilePhoto(
        userId: user.id,
        imageBase64: imageBase64,
      );

      final updated = response['user'];
      if (updated is Map<String, dynamic>) {
        SessionStore.currentUser = SessionUser.fromJson(updated);
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

  String _resolveMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionStore.currentUser;

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Perfil y demos',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: user?.profilePhotoUrl == null
                          ? null
                          : NetworkImage(user!.profilePhotoUrl!),
                      child: user?.profilePhotoUrl == null
                          ? Text((user?.firstName ?? 'U').substring(0, 1))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Usuario',
                            style: const TextStyle(fontSize: 22),
                          ),
                          Text((user?.type ?? 'user').toUpperCase()),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _updatingPhoto
                                    ? null
                                    : _pickAndUploadPhoto,
                                icon: const Icon(
                                  Icons.photo_camera_back_outlined,
                                ),
                                label: Text(
                                  _updatingPhoto
                                      ? 'Guardando...'
                                      : 'Cambiar foto',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _updatingPhoto ||
                                        user?.profilePhotoUrl == null
                                    ? null
                                    : _removePhoto,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _NavTile(
                title: 'Radar de trabajo',
                subtitle: 'Toggle disponible/no disponible + mapa',
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
                title: 'Seleccion de habilidades',
                subtitle: 'Paso de onboarding del trabajador',
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
                title: 'Rastreo de servicio',
                subtitle: 'Tracking de llegada + acciones',
                icon: Icons.location_searching,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TrackingScreen(),
                    ),
                  );
                },
              ),
              _NavTile(
                title: 'Estado sin solicitudes',
                subtitle: 'Vista vacia + refresh',
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
                title: 'Calificacion final',
                subtitle: 'Rating con estrellas y comentario',
                icon: Icons.star_rate,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RatingScreen(),
                    ),
                  );
                },
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
