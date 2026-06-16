import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../domain/usecases/worker_usecases.dart';
import '../state/worker_dependencies.dart';
import 'verification_checkpoint_screen.dart';

/// Paso del registro (y edición de perfil) donde el trabajador define con qué
/// modalidades quiere cobrar: por trabajo, por hora y/o por día. Las tarifas
/// son solo un punto de partida y no el precio final que negocia con el cliente.
class WorkModalitiesScreen extends StatefulWidget {
  const WorkModalitiesScreen({
    this.getWorkerModalitiesUseCase,
    this.updateWorkerModalitiesUseCase,
    this.forceToHomeAfterSave = false,
    super.key,
  });

  /// En el registro (true) avanza al checkpoint de verificación; en edición de
  /// perfil (false) simplemente vuelve atrás.
  final bool forceToHomeAfterSave;
  final GetWorkerModalitiesUseCase? getWorkerModalitiesUseCase;
  final UpdateWorkerModalitiesUseCase? updateWorkerModalitiesUseCase;

  @override
  State<WorkModalitiesScreen> createState() => _WorkModalitiesScreenState();
}

class _WorkModalitiesScreenState extends State<WorkModalitiesScreen> {
  GetWorkerModalitiesUseCase get _getModalities =>
      widget.getWorkerModalitiesUseCase ??
      WorkerDependencies.getWorkerModalities;
  UpdateWorkerModalitiesUseCase get _updateModalities =>
      widget.updateWorkerModalitiesUseCase ??
      WorkerDependencies.updateWorkerModalities;

  final Set<String> _selected = <String>{};
  final _hourlyRateController = TextEditingController();
  final _dailyRateController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hourlyRateController.dispose();
    _dailyRateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    final result = await _getModalities(workerUserId: user.id);
    result.fold(
      onSuccess: (modalities) {
        _selected
          ..clear()
          ..addAll(modalities.modalities);
        if (modalities.hourlyRate != null) {
          _hourlyRateController.text =
              modalities.hourlyRate!.toStringAsFixed(0);
        }
        if (modalities.dailyRate != null) {
          _dailyRateController.text = modalities.dailyRate!.toStringAsFixed(0);
        }
      },
      onFailure: (_) {},
    );
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _toggle(String modality) {
    setState(() {
      if (_selected.contains(modality)) {
        _selected.remove(modality);
      } else {
        _selected.add(modality);
      }
    });
  }

  Future<void> _save() async {
    final user = SessionStore.currentUser;
    if (user == null) return;

    if (_selected.isEmpty) {
      _showMessage('Selecciona al menos una modalidad de trabajo');
      return;
    }

    double? hourlyRate;
    double? dailyRate;

    if (_selected.contains('hourly')) {
      hourlyRate = double.tryParse(_hourlyRateController.text.trim());
      if (hourlyRate == null || hourlyRate <= 0) {
        _showMessage('Ingresa tu tarifa por hora');
        return;
      }
    }
    if (_selected.contains('daily')) {
      dailyRate = double.tryParse(_dailyRateController.text.trim());
      if (dailyRate == null || dailyRate <= 0) {
        _showMessage('Ingresa tu tarifa por día');
        return;
      }
    }

    setState(() => _saving = true);
    final result = await _updateModalities(
      workerUserId: user.id,
      modalities: _selected.toList(),
      hourlyRate: hourlyRate,
      dailyRate: dailyRate,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      onSuccess: (_) {
        _showMessage('Modalidades guardadas');
        if (widget.forceToHomeAfterSave) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => const VerificationCheckpointScreen(),
            ),
            (_) => false,
          );
        } else {
          Navigator.of(context).pop();
        }
      },
      onFailure: (failure) => _showMessage(failure.message),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      'Perfil de Trabajador',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 10),
                if (widget.forceToHomeAfterSave) ...[
                  const Text(
                    'Paso 3 de 5',
                    style: TextStyle(color: AppTheme.colorMuted),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.6,
                    backgroundColor:
                        AppTheme.colorPrimary.withValues(alpha: 0.2),
                    color: AppTheme.colorPrimary,
                    borderRadius: BorderRadius.circular(20),
                    minHeight: 10,
                  ),
                  const SizedBox(height: 22),
                ] else
                  const SizedBox(height: 16),
                if (_loading) const LinearProgressIndicator(),
                Text(
                  '¿Cómo quieres cobrar?',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige una o varias modalidades. Puedes cambiarlas después '
                  'desde tu perfil.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.colorMuted,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      _ModalityCheck(
                        icon: Icons.work_outline,
                        title: 'Por trabajo',
                        description:
                            'Precio cerrado: acuerdas un monto fijo por todo '
                            'el trabajo.',
                        selected: _selected.contains('fixed'),
                        onTap: () => _toggle('fixed'),
                      ),
                      const SizedBox(height: 12),
                      _ModalityCheck(
                        icon: Icons.access_time,
                        title: 'Por hora',
                        description:
                            'Cobras por las horas trabajadas. Indica una tarifa '
                            'de referencia.',
                        selected: _selected.contains('hourly'),
                        onTap: () => _toggle('hourly'),
                        rateField: _selected.contains('hourly')
                            ? _RateField(
                                controller: _hourlyRateController,
                                label: 'Tu tarifa por hora',
                                suffix: 'Bs / hr',
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _ModalityCheck(
                        icon: Icons.calendar_today_outlined,
                        title: 'Por día',
                        description:
                            'Cobras por jornada completa. Indica una tarifa de '
                            'referencia.',
                        selected: _selected.contains('daily'),
                        onTap: () => _toggle('daily'),
                        rateField: _selected.contains('daily')
                            ? _RateField(
                                controller: _dailyRateController,
                                label: 'Tu tarifa por día',
                                suffix: 'Bs / día',
                              )
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.colorHighlightSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.colorHighlight
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.colorHighlight, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Estas tarifas son solo un punto de partida '
                                'para mostrar a los clientes. El precio final '
                                'siempre lo negocias tú con cada cliente.',
                                style: TextStyle(
                                  color: AppTheme.colorText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ChambaPrimaryButton(
                  label: _saving
                      ? 'Guardando...'
                      : (widget.forceToHomeAfterSave ? 'Continuar' : 'Guardar'),
                  onPressed: _saving || _loading ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalityCheck extends StatelessWidget {
  const _ModalityCheck({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.rateField,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final Widget? rateField;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.colorPrimary.withValues(alpha: 0.1)
            : AppTheme.colorSurfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppTheme.colorPrimary
              : AppTheme.colorGlassBorderSoft,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        AppTheme.colorPrimary.withValues(alpha: 0.35),
                    child: Icon(icon, size: 24, color: AppTheme.colorText),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.colorMuted,
                                height: 1.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CheckBox(selected: selected),
                ],
              ),
            ),
          ),
          if (rateField != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: rateField,
            ),
        ],
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? AppTheme.colorHighlight : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppTheme.colorHighlight : AppTheme.colorGlassBorder,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 18, color: AppTheme.colorText)
          : null,
    );
  }
}

class _RateField extends StatelessWidget {
  const _RateField({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      style: const TextStyle(color: AppTheme.colorText),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: AppTheme.colorGlassInputSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
