import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';

class SkillsSelectionScreen extends StatefulWidget {
  const SkillsSelectionScreen({this.forceToHomeAfterSave = false, super.key});

  final bool forceToHomeAfterSave;

  @override
  State<SkillsSelectionScreen> createState() => _SkillsSelectionScreenState();
}

class _SkillsSelectionScreenState extends State<SkillsSelectionScreen> {
  final Set<String> selected = <String>{};
  bool _loading = true;
  List<(String, IconData)> _skills = const [
    ('Construccion', Icons.handyman),
    ('Electricidad', Icons.flash_on),
    ('Plomeria', Icons.plumbing),
    ('Jardineria', Icons.yard),
    ('Transporte', Icons.local_shipping),
    ('Limpieza', Icons.cleaning_services),
    ('Mecanica', Icons.work),
    ('Carpinteria', Icons.architecture),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final categoriesResponse = await MobileBackendService.categories();
      final categories =
          (categoriesResponse['categories'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map((item) => item['name']?.toString().trim() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
      if (categories.isNotEmpty) {
        _skills = categories.map((name) => (name, _resolveIcon(name))).toList();
      }

      final response = await MobileBackendService.workerSkills(
        workerUserId: user.id,
      );
      final values = (response['skills'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toSet();
      selected
        ..clear()
        ..addAll(values);
    } catch (_) {
      selected
        ..clear()
        ..addAll(const {'Construccion', 'Plomeria'});
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  IconData _resolveIcon(String label) {
    final value = label.toLowerCase();
    if (value.contains('elect')) return Icons.flash_on;
    if (value.contains('plom') || value.contains('gas')) return Icons.plumbing;
    if (value.contains('jardin')) return Icons.yard;
    if (value.contains('transp') || value.contains('logis')) {
      return Icons.local_shipping;
    }
    if (value.contains('limp')) return Icons.cleaning_services;
    if (value.contains('mecan')) return Icons.build;
    if (value.contains('carpint')) return Icons.architecture;
    if (value.contains('pint')) return Icons.format_paint;
    return Icons.handyman;
  }

  Future<void> _save() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _loading = true);

    try {
      await MobileBackendService.updateWorkerSkills(
        workerUserId: user.id,
        skills: selected.toList(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Habilidades guardadas: ${selected.length}')),
      );
      if (widget.forceToHomeAfterSave) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => MainShellScreen(
              role: SessionStore.currentUser?.type ?? 'worker',
            ),
          ),
          (_) => false,
        );
      } else {
        Navigator.of(context).pop();
      }
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
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Spacer(),
                    Text(
                      'Perfil de Trabajador',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Paso 4 de 5',
                  style: TextStyle(color: AppTheme.colorMuted),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.8,
                  backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.2),
                  color: AppTheme.colorPrimary,
                  borderRadius: BorderRadius.circular(20),
                  minHeight: 10,
                ),
                const SizedBox(height: 22),
                if (_loading) const LinearProgressIndicator(),
                Text(
                  'En que eres bueno?',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: _skills.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                    itemBuilder: (context, index) {
                      final (label, icon) = _skills[index];
                      final isSelected = selected.contains(label);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selected.remove(label);
                            } else {
                              selected.add(label);
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.colorPrimary.withValues(alpha: 0.1)
                                : AppTheme.colorSurfaceSoft,
                            borderRadius: BorderRadius.circular(34),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.colorPrimary
                                  : const Color(0xFFCBD4E9),
                              width: 2,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (isSelected)
                                const Positioned(
                                  right: 10,
                                  top: 10,
                                  child: CircleAvatar(
                                    radius: 13,
                                    backgroundColor: AppTheme.colorHighlight,
                                    child: Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: AppTheme.colorPrimary
                                          .withValues(alpha: 0.35),
                                      child: Icon(icon, size: 30),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                ChambaPrimaryButton(
                  label: _loading ? 'Guardando...' : 'Continuar',
                  onPressed: _loading ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
