import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../request/presentation/state/request_dependencies.dart';

class ClientCounterOfferScreen extends StatefulWidget {
  const ClientCounterOfferScreen({
    required this.requestId,
    required this.currentBudget,
    required this.originalBudget,
    required this.workerName,
    required this.workerOffer,
    super.key,
  });

  final String requestId;
  final double currentBudget;
  final double originalBudget;
  final String workerName;
  final double workerOffer;

  @override
  State<ClientCounterOfferScreen> createState() =>
      _ClientCounterOfferScreenState();
}

class _ClientCounterOfferScreenState extends State<ClientCounterOfferScreen> {
  late double _selectedAmount;
  bool _loading = false;
  bool _editingManually = false;
  final TextEditingController _manualCtrl = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  double get _base => widget.currentBudget;

  @override
  void initState() {
    super.initState();
    _selectedAmount = _pct(5);
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    _manualFocus.dispose();
    super.dispose();
  }

  /// Presets porcentuales sobre la oferta actual (igual que el trabajador):
  /// +5%, +10%, +20%. Se redondea hacia abajo para trabajar con enteros.
  double _pct(double pct) {
    final v = _base * (1 + pct / 100);
    final floored = v.floorToDouble();
    // La contraoferta del cliente debe ser estrictamente mayor a la actual;
    // en presupuestos pequeños el redondeo podría igualar la base.
    return floored > _base ? floored : _base + 1;
  }

  void _selectPreset(double amount) {
    setState(() {
      _selectedAmount = amount;
      _editingManually = false;
    });
  }

  void _openManualEdit() {
    _manualCtrl.text = _selectedAmount.toInt().toString();
    setState(() => _editingManually = true);
    Future.delayed(const Duration(milliseconds: 80), () {
      _manualFocus.requestFocus();
    });
  }

  void _applyManualEdit() {
    final parsed = double.tryParse(_manualCtrl.text.trim());
    if (parsed != null && parsed > 0) {
      setState(() {
        _selectedAmount = parsed.floorToDouble();
        _editingManually = false;
      });
    } else {
      setState(() => _editingManually = false);
    }
  }

  Future<void> _sendOffer() async {
    final user = SessionStore.currentUser;
    if (user == null) return;

    final selectedInt = _selectedAmount.toInt();
    final currentInt = widget.currentBudget.toInt();

    if (selectedInt <= currentInt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tu contraoferta debe ser mayor a tu oferta actual (Bs $currentInt)',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      (await RequestDependencies.clientCounterOffer(
        requestId: widget.requestId,
        clientUserId: user.id,
        amount: _selectedAmount,
      )).fold(
        onSuccess: (_) {},
        onFailure: (failure) => throw Exception(failure.message),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraoferta enviada correctamente')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s5 = _pct(5);
    final s10 = _pct(10);
    final s20 = _pct(20);
    final originalInt = widget.originalBudget.toInt();
    final workerOfferInt = widget.workerOffer.toInt();

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                    const Spacer(),
                    const Text(
                      'HACER CONTRAOFERTA',
                      style: TextStyle(
                        color: AppTheme.colorPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Info de la oferta del worker ────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.colorSurfaceSoft,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${widget.workerName} te ofreció: Bs $workerOfferInt',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tu presupuesto original: Bs $originalInt',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.colorMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Precio propuesto ─────────────────────────────────────
                Text(
                  'Tu nueva oferta',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppTheme.colorMuted),
                ),
                const SizedBox(height: 10),

                if (_editingManually)
                  Center(
                    child: SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _manualCtrl,
                        focusNode: _manualFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: false,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          prefixText: 'Bs ',
                          prefixStyle: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: AppTheme.colorMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppTheme.colorPrimary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppTheme.colorPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _applyManualEdit(),
                      ),
                    ),
                  )
                else
                  Text(
                    'Bs ${_selectedAmount.toInt()}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                const SizedBox(height: 28),

                // ── Botones de atajo ─────────────────────────────────────
                Row(
                  children: [
                    _PresetButton(
                      label: 'Bs ${s5.toInt()}',
                      selected: !_editingManually && _selectedAmount == s5,
                      onTap: () => _selectPreset(s5),
                    ),
                    const SizedBox(width: 8),
                    _PresetButton(
                      label: 'Bs ${s10.toInt()}',
                      selected: !_editingManually && _selectedAmount == s10,
                      onTap: () => _selectPreset(s10),
                    ),
                    const SizedBox(width: 8),
                    _PresetButton(
                      label: 'Bs ${s20.toInt()}',
                      selected: !_editingManually && _selectedAmount == s20,
                      onTap: () => _selectPreset(s20),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _editingManually
                          ? _applyManualEdit
                          : _openManualEdit,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _editingManually
                              ? AppTheme.colorPrimary
                              : AppTheme.colorSurfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _editingManually
                                ? AppTheme.colorPrimary
                                : AppTheme.colorGlassBorderSoft,
                          ),
                          boxShadow: _editingManually
                              ? [
                                  BoxShadow(
                                    color: AppTheme.colorPrimary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : const [],
                        ),
                        child: Center(
                          child: Icon(
                            _editingManually ? Icons.check : Icons.edit,
                            color: _editingManually
                                ? Colors.white
                                : AppTheme.colorMuted,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // ── Enviar ───────────────────────────────────────────────
                ChambaPrimaryButton(
                  label: _loading ? 'Enviando...' : 'Enviar contraoferta',
                  icon: Icons.send,
                  onPressed: _loading ? null : _sendOffer,
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 64,
          decoration: BoxDecoration(
            color: selected ? AppTheme.colorPrimary : AppTheme.colorSurfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.colorPrimary
                  : AppTheme.colorGlassBorderSoft,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.colorPrimary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.colorMuted,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
