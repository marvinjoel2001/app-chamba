import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../request/presentation/screens/request_form_screen.dart';
import '../../../request/presentation/screens/request_status_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({required this.role, super.key});

  final String role;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _workers = const [];
  List<dynamic> _categories = const [];
  Map<String, dynamic>? _activeRequest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesion expirada. Inicia sesion de nuevo.';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await MobileBackendService.explore(userId: user.id);
      final activeRequest = response['activeRequest'];
      if (activeRequest is Map<String, dynamic>) {
        SessionStore.activeRequestId = activeRequest['id'] as String?;
      }

      setState(() {
        _workers = (response['nearbyWorkers'] as List<dynamic>? ?? const []);
        _categories = (response['categories'] as List<dynamic>? ?? const []);
        _activeRequest = activeRequest is Map<String, dynamic> ? activeRequest : null;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionStore.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          const ChambaBackground(showGrid: true, child: SizedBox.expand()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0x1A6B2BBE),
                        child: const Icon(Icons.work_history),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        user == null ? 'Chamba' : 'Hola, ${user.firstName}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: user?.profilePhotoUrl == null
                            ? null
                            : NetworkImage(user!.profilePhotoUrl!),
                        child: user?.profilePhotoUrl == null
                            ? Text((user?.firstName ?? 'U').substring(0, 1).toUpperCase())
                            : null,
                      ),
                    ],
                  ),
                  const Spacer(),
                  _MapDots(workers: _workers),
                ],
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Positioned(
              left: 20,
              right: 20,
              top: 110,
              child: GlassCard(
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 300,
            child: Column(
              children: [
                const _MapControl(icon: Icons.add),
                const SizedBox(height: 12),
                const _MapControl(icon: Icons.remove),
                const SizedBox(height: 12),
                _MapControl(
                  icon: Icons.navigation,
                  highlighted: true,
                  onTap: _load,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassCard(
              borderRadius: 32,
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCFD6E8),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _activeRequest == null
                              ? 'Sin solicitudes activas'
                              : 'Solicitud activa: ${_activeRequest!['title']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.colorHighlight,
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RequestFormScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < _categories.length; i++) ...[
                          ChambaChip(
                            label: _categories[i].toString(),
                            selected: i == 0,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (_categories.isEmpty) const ChambaChip(label: 'Sin categorias', selected: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChambaPrimaryButton(
                          label: widget.role == 'worker'
                              ? 'Ver solicitudes cercanas'
                              : 'Estado solicitud',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RequestStatusScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Trabajadores cercanos: ${_workers.length}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    this.highlighted = false,
    this.onTap,
  });

  final IconData icon;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppTheme.colorSurfaceSoft,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: highlighted ? AppTheme.colorHighlight : AppTheme.colorText),
      ),
    );
  }
}

class _MapDots extends StatelessWidget {
  const _MapDots({required this.workers});

  final List<dynamic> workers;

  @override
  Widget build(BuildContext context) {
    final count = workers.length;

    return Stack(
      children: [
        if (count > 0)
          Positioned(
            left: 30,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.6),
            ),
          ),
        if (count > 1)
          Positioned(
            left: 180,
            top: 120,
            child: CircleAvatar(
              radius: 8,
              backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.55),
            ),
          ),
        if (count > 2)
          Positioned(
            left: 60,
            top: 220,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.6),
            ),
          ),
        Center(
          child: CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.colorHighlight,
            child: Icon(Icons.location_on, color: Colors.black.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }
}
