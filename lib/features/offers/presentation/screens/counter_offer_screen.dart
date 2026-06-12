import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../state/offers_dependencies.dart';

class CounterOfferScreen extends StatefulWidget {
  const CounterOfferScreen({
    this.requestId,
    this.workerId,
    this.originalBudget,
    this.requestData,
    super.key,
  });

  final String? requestId;
  final String? workerId;
  final double? originalBudget;
  final Map<String, dynamic>? requestData;

  @override
  State<CounterOfferScreen> createState() => _CounterOfferScreenState();
}

class _CounterOfferScreenState extends State<CounterOfferScreen> {
  late double _selectedAmount;
  bool _loading = false;
  bool _editingManually = false;
  final TextEditingController _manualCtrl = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  double get _base => widget.originalBudget ?? 100;

  String _priceTypeSuffix() {
    final raw = widget.requestData?['priceType']?.toString() ??
        widget.requestData?['price_type']?.toString() ??
        '';
    if (raw.contains('hora')) return '/hora';
    if (raw.contains('full') || raw.contains('fijo')) return ' (precio fijo)';
    return '/día';
  }

  String _priceLabel() =>
      'Oferta original: Bs ${_base.toInt()}${_priceTypeSuffix()}';

  @override
  void initState() {
    super.initState();
    _selectedAmount = _base;
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    _manualFocus.dispose();
    super.dispose();
  }

  double _pct(double pct) {
    final v = _base * (1 + pct / 100);
    return double.parse(v.toStringAsFixed(0));
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
        _selectedAmount = parsed;
        _editingManually = false;
      });
    } else {
      setState(() => _editingManually = false);
    }
  }

  Future<void> _sendOffer() async {
    final user = SessionStore.currentUser;
    final requestId = widget.requestId ?? SessionStore.activeRequestId;
    if (user == null || requestId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No hay solicitud activa.')));
      return;
    }
    // Validación: Worker debe estar verificado
    final isVerified = user.verificationStatus == 'verified' ||
        (user.idPhotoVerified == true && user.facePhotoVerified == true);
    if (!isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes verificar tu identidad antes de enviar ofertas.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      // Opcional: navegar a pantalla de verificación
      // Navigator.of(context).pushNamed('/verification');
      return;
    }
    // Aplicar edición manual pendiente si la hay
    if (_editingManually) {
      final parsed = double.tryParse(_manualCtrl.text.trim());
      if (parsed != null && parsed > 0) {
        _selectedAmount = parsed;
        _editingManually = false;
      }
    }
    // Validación: la oferta debe ser mayor a 0
    final selectedInt = _selectedAmount.toInt();
    if (selectedInt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      (await OffersDependencies.counterOffer(
        requestId: requestId,
        workerUserId: widget.workerId ?? user.id,
        amount: _selectedAmount,
      ))
          .fold(
        onSuccess: (value) => value,
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

  void _showJobDetails() {
    final req = widget.requestData;
    if (req == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JobDetailsSheet(requestData: req),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p5 = _pct(5);
    final p10 = _pct(10);
    final p20 = _pct(20);

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

                // ── Oferta original ──────────────────────────────────────
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
                    child: Text(
                      _priceLabel(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Precio propuesto ─────────────────────────────────────
                Text(
                  'Tu precio propuesto',
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
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
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
                    'Bs ${_selectedAmount.toInt()}${_priceTypeSuffix()}',
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
                      label: 'Bs ${p5.toInt()}',
                      selected: !_editingManually && _selectedAmount == p5,
                      onTap: () => _selectPreset(p5),
                    ),
                    const SizedBox(width: 8),
                    _PresetButton(
                      label: 'Bs ${p10.toInt()}',
                      selected: !_editingManually && _selectedAmount == p10,
                      onTap: () => _selectPreset(p10),
                    ),
                    const SizedBox(width: 8),
                    _PresetButton(
                      label: 'Bs ${p20.toInt()}',
                      selected: !_editingManually && _selectedAmount == p20,
                      onTap: () => _selectPreset(p20),
                    ),
                    const SizedBox(width: 8),
                    // Botón lápiz (editar manual)
                    GestureDetector(
                      onTap:
                          _editingManually ? _applyManualEdit : _openManualEdit,
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

                const SizedBox(height: 16),

                // ── Ver detalles del trabajo ─────────────────────────────
                if (widget.requestData != null)
                  TextButton.icon(
                    onPressed: _showJobDetails,
                    icon: const Icon(
                      Icons.info_outline,
                      color: AppTheme.colorHighlight,
                      size: 18,
                    ),
                    label: const Text(
                      'Ver detalles del trabajo',
                      style: TextStyle(
                        color: AppTheme.colorHighlight,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),

                const Spacer(),

                // ── Enviar ───────────────────────────────────────────────
                ChambaPrimaryButton(
                  label: _loading ? 'Enviando...' : 'Enviar oferta',
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

// ── Modal de detalles del trabajo ─────────────────────────────────────────────
class _JobDetailsSheet extends StatelessWidget {
  const _JobDetailsSheet({required this.requestData});

  final Map<String, dynamic> requestData;

  @override
  Widget build(BuildContext context) {
    final title = requestData['title']?.toString() ?? 'Solicitud';
    final description = requestData['description']?.toString() ?? '';
    final address = requestData['address']?.toString() ?? '';
    final budget = requestData['budget'];
    final priceType = requestData['priceType']?.toString() ??
        requestData['price_type']?.toString() ?? '';
    final category = requestData['category']?.toString() ?? '';
    final distanceKm = requestData['distanceKm'];
    final photos = requestData['photos'] as List<dynamic>? ?? const [];
    final client = requestData['client'] as Map<String, dynamic>?;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1728),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.colorMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Título
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),

              // Categoría + presupuesto
              Row(
                children: [
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.colorPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppTheme.colorPrimaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (budget != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (priceType.isNotEmpty)
                          Text(
                            priceType,
                            style: const TextStyle(
                              color: AppTheme.colorMuted,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          'Bs $budget',
                          style: const TextStyle(
                            color: AppTheme.colorHighlight,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Descripción
              if (description.isNotEmpty) ...[
                const Text(
                  'Descripción',
                  style: TextStyle(
                    color: AppTheme.colorMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.colorText,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Ubicación
              if (address.isNotEmpty) ...[
                const Text(
                  'Ubicación',
                  style: TextStyle(
                    color: AppTheme.colorMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppTheme.colorPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          color: AppTheme.colorText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (distanceKm != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.straighten,
                        color: AppTheme.colorMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'A ${(distanceKm as num).toStringAsFixed(1)} km de tu ubicación',
                        style: const TextStyle(
                          color: AppTheme.colorMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // Cliente
              if (client != null) ...[
                const Text(
                  'Cliente',
                  style: TextStyle(
                    color: AppTheme.colorMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChambaNetworkAvatar(
                      url: client['profilePhotoUrl'] as String?,
                      radius: 22,
                      fallbackText: (client['firstName'] ?? 'C')
                          .toString()
                          .substring(0, 1),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${client['firstName'] ?? ''} ${client['lastName'] ?? ''}'
                          .trim(),
                      style: const TextStyle(
                        color: AppTheme.colorText,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Fotos
              if (photos.isNotEmpty) ...[
                const Text(
                  'Fotos',
                  style: TextStyle(
                    color: AppTheme.colorMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final photo = photos[i];
                      final url =
                          (photo is Map ? photo['url'] : photo)?.toString();
                      if (url == null) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                backgroundColor: Colors.black,
                                body: SafeArea(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      InteractiveViewer(
                                        child: ChambaNetworkImage(
                                          url: url,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: IconButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ChambaNetworkImage(
                            url: url,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Botón de preset ───────────────────────────────────────────────────────────
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
                color: selected ? Colors.white : AppTheme.colorText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
