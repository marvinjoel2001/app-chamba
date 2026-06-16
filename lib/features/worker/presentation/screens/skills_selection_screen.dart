import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import 'work_modalities_screen.dart';
import '../../domain/entities/worker_category.dart';
import '../../domain/usecases/worker_usecases.dart';
import '../state/worker_dependencies.dart';

class SkillsSelectionScreen extends StatefulWidget {
  const SkillsSelectionScreen({
    this.getWorkerCategoriesUseCase,
    this.getWorkerSkillsUseCase,
    this.createWorkerCategoryUseCase,
    this.updateWorkerSkillsUseCase,
    this.forceToHomeAfterSave = false,
    super.key,
  });

  final bool forceToHomeAfterSave;
  final GetWorkerCategoriesUseCase? getWorkerCategoriesUseCase;
  final GetWorkerSkillsUseCase? getWorkerSkillsUseCase;
  final CreateWorkerCategoryUseCase? createWorkerCategoryUseCase;
  final UpdateWorkerSkillsUseCase? updateWorkerSkillsUseCase;

  @override
  State<SkillsSelectionScreen> createState() => _SkillsSelectionScreenState();
}

class _SkillsSelectionScreenState extends State<SkillsSelectionScreen> {
  GetWorkerCategoriesUseCase get _getWorkerCategoriesUseCase =>
      widget.getWorkerCategoriesUseCase ??
      WorkerDependencies.getWorkerCategories;
  GetWorkerSkillsUseCase get _getWorkerSkillsUseCase =>
      widget.getWorkerSkillsUseCase ?? WorkerDependencies.getWorkerSkills;
  CreateWorkerCategoryUseCase get _createWorkerCategoryUseCase =>
      widget.createWorkerCategoryUseCase ??
      WorkerDependencies.createWorkerCategory;
  UpdateWorkerSkillsUseCase get _updateWorkerSkillsUseCase =>
      widget.updateWorkerSkillsUseCase ?? WorkerDependencies.updateWorkerSkills;

  final Set<String> selected = <String>{};
  bool _loading = true;
  bool _isOffline = false;
  bool _shouldRedirectToLogin = false;
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
    final categoriesResult = await _getWorkerCategoriesUseCase();
    categoriesResult.fold(
      onSuccess: (categories) {
        final names = categories
            .map((item) => item.name.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false);
        if (names.isNotEmpty) {
          _skills = names.map((name) => (name, _resolveIcon(name))).toList();
        }
      },
      onFailure: (_) {},
    );

    final skillsResult = await _getWorkerSkillsUseCase(workerUserId: user.id);
    skillsResult.fold(
      onSuccess: (skills) {
        selected
          ..clear()
          ..addAll(skills.map((item) => item.name));
        if (!mounted) {
          return;
        }
        setState(() {
          _isOffline = false;
          _shouldRedirectToLogin = false;
          _loading = false;
        });
      },
      onFailure: (failure) {
        selected
          ..clear()
          ..addAll(const {'Construccion', 'Plomeria'});
        if (!mounted) {
          return;
        }
        setState(() {
          _isOffline = failure is NetworkFailure;
          _shouldRedirectToLogin = failure is UnauthorizedFailure;
          _loading = false;
        });
      },
    );
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

  Future<void> _createCategoryFromDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final created = await showDialog<String>(
      context: context,
      builder: (context) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nueva categoria'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Instalacion de paneles',
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) {
                      return 'Ingresa un nombre';
                    }
                    if (name.length < 3) {
                      return 'Minimo 3 caracteres';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() => saving = true);
                          final name = controller.text.trim();
                          final result = await _createWorkerCategoryUseCase(
                            name: name,
                          );
                          result.fold(
                            onSuccess: (WorkerCategory category) {
                              if (!context.mounted) {
                                return;
                              }
                              Navigator.of(context).pop(category.name);
                            },
                            onFailure: (failure) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(failure.message)),
                              );
                              setDialogState(() => saving = false);
                            },
                          );
                        },
                  child: Text(saving ? 'Guardando...' : 'Crear'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (created == null || created.isEmpty || !mounted) {
      return;
    }

    await _load();
    setState(() {
      selected.add(created);
    });
  }

  Future<void> _save() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      return;
    }

    // Validar que se seleccionen entre 1 y 5 categorías
    if (selected.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos 1 habilidad')),
      );
      return;
    }

    if (selected.length > 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona máximo 5 habilidades')),
      );
      return;
    }

    setState(() => _loading = true);
    final result = await _updateWorkerSkillsUseCase(
      workerUserId: user.id,
      skills: selected.toList(),
    );
    result.fold(
      onSuccess: (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Habilidades guardadas: ${selected.length}')),
        );
        if (widget.forceToHomeAfterSave) {
          // Siguiente paso del registro: elegir modalidades de cobro.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const WorkModalitiesScreen(forceToHomeAfterSave: true),
            ),
            (_) => false,
          );
        } else {
          Navigator.of(context).pop();
        }
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
      setState(() => _loading = false);
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                if (_isOffline)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Sin conexión. Intenta nuevamente.'),
                  ),
                if (_shouldRedirectToLogin)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Sesión expirada. Inicia sesión nuevamente.'),
                  ),
                if (widget.forceToHomeAfterSave) ...[
                  const Text(
                    'Paso 2 de 5',
                    style: TextStyle(color: AppTheme.colorMuted),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.4,
                    backgroundColor:
                        AppTheme.colorPrimary.withValues(alpha: 0.2),
                    color: AppTheme.colorPrimary,
                    borderRadius: BorderRadius.circular(20),
                    minHeight: 10,
                  ),
                  const SizedBox(height: 22),
                ] else ...[
                  const SizedBox(height: 16),
                ],
                if (_loading) const LinearProgressIndicator(),
                Text(
                  '¿Qué habilidades tienes?',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Puedes cambiar esto después desde tu perfil',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.colorMuted,
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
                                  : AppTheme.colorGlassBorderSoft,
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
                                      color: AppTheme.colorText,
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
