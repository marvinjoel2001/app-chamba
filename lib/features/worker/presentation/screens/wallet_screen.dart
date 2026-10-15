import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_visuals.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../domain/entities/worker_job.dart';
import '../../domain/usecases/worker_usecases.dart';
import '../state/worker_dependencies.dart';

enum _DateFilter { today, last3days, thisWeek, thisMonth, all }

extension _DateFilterLabel on _DateFilter {
  String get label {
    switch (this) {
      case _DateFilter.today:
        return 'Hoy';
      case _DateFilter.last3days:
        return 'Últimos 3 días';
      case _DateFilter.thisWeek:
        return 'Esta semana';
      case _DateFilter.thisMonth:
        return 'Este mes';
      case _DateFilter.all:
        return 'Total';
    }
  }
}

class WalletScreen extends StatefulWidget {
  const WalletScreen(
      {this.getWorkerHistoryUseCase,
      this.onFindJobs,
      this.isActive = true,
      super.key});

  final GetWorkerHistoryUseCase? getWorkerHistoryUseCase;
  final VoidCallback? onFindJobs;
  final bool isActive;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with WidgetsBindingObserver {
  GetWorkerHistoryUseCase get _getWorkerHistoryUseCase =>
      widget.getWorkerHistoryUseCase ?? WorkerDependencies.getWorkerHistory;

  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  List<WorkerJob> _allJobs = const [];
  _DateFilter _filter = _DateFilter.thisWeek;
  final _realtime = RealtimeService.instance;
  bool _fetching = false, _reloadPending = false;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtime.on('job.completed', _onJobCompleted);
    _realtime.reconnectCount.addListener(_refreshWhenActive);
    if (widget.isActive) _load();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _realtime.off('job.completed', _onJobCompleted);
    _realtime.reconnectCount.removeListener(_refreshWhenActive);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onJobCompleted(dynamic _) => _refreshWhenActive();

  void _refreshWhenActive() {
    if (!widget.isActive) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted && widget.isActive) _load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshWhenActive();
  }

  @override
  void didUpdateWidget(covariant WalletScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive &&
        (!oldWidget.isActive ||
            oldWidget.getWorkerHistoryUseCase !=
                widget.getWorkerHistoryUseCase)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_fetching) {
      _reloadPending = true;
      return;
    }
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesión expirada';
        _loading = false;
      });
      return;
    }
    _fetching = true;
    setState(() {
      // Solo la primera carga muestra el placeholder; las recargas al volver
      // a la pestaña mantienen el saldo visible hasta tener datos nuevos.
      _loading = !_hasLoaded;
      _error = null;
    });
    try {
      final result = await _getWorkerHistoryUseCase(workerUserId: user.id);
      result.fold(
        onSuccess: (jobs) {
          if (!mounted || SessionStore.currentUser?.id != user.id) {
            return;
          }
          setState(() {
            _allJobs = jobs;
            _hasLoaded = true;
            _loading = false;
          });
        },
        onFailure: (failure) {
          if (!mounted || SessionStore.currentUser?.id != user.id) {
            return;
          }
          setState(() {
            _error = failure.message;
            _loading = false;
          });
        },
      );
    } finally {
      _fetching = false;
      if (_reloadPending) {
        _reloadPending = false;
        if (mounted && widget.isActive) unawaited(_load());
      }
    }
  }

  /// Filtra los trabajos según el período seleccionado (solo completados)
  List<WorkerJob> get _filteredJobs {
    // Solo mostrar trabajos completados en la billetera
    final completed = _allJobs.where((job) => job.isEarned).toList();

    if (_filter == _DateFilter.all) return completed;

    final now = DateTime.now();
    DateTime cutoff;
    switch (_filter) {
      case _DateFilter.today:
        cutoff = DateTime(now.year, now.month, now.day);
        break;
      case _DateFilter.last3days:
        cutoff = now.subtract(const Duration(days: 3));
        break;
      case _DateFilter.thisWeek:
        cutoff = now.subtract(Duration(days: now.weekday - 1));
        cutoff = DateTime(cutoff.year, cutoff.month, cutoff.day);
        break;
      case _DateFilter.thisMonth:
        cutoff = DateTime(now.year, now.month, 1);
        break;
      case _DateFilter.all:
        return _allJobs;
    }

    return completed
        .where(
          (job) =>
              job.completedAt != null && !job.completedAt!.isBefore(cutoff),
        )
        .toList();
  }

  double get _totalEarnings {
    return _filteredJobs.fold(0.0, (sum, job) => sum + job.amount);
  }

  bool get _hasNonCashEarnings {
    return _allJobs.any((job) => job.isEarned && job.isNonCashPayment);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    return dateTimeLabel(value, relative: false);
  }

  IconData _categoryIcon(String? category) => CategoryVisual.of(category).icon;

  Color _categoryColor(String? category) => CategoryVisual.of(category).color;

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _DateFilter.values.map((f) {
              return ListTile(
                title: Text(
                  f.label,
                  style: TextStyle(
                    color: _filter == f
                        ? AppTheme.colorPrimary
                        : AppTheme.colorText,
                    fontWeight:
                        _filter == f ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: _filter == f
                    ? const Icon(Icons.check, color: AppTheme.colorPrimary)
                    : null,
                onTap: () {
                  setState(() => _filter = f);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredJobs;
    final total = _totalEarnings;

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Text(
                    'Mi Billetera',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.colorText,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, color: AppTheme.colorMuted),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.colorPrimary,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF8B5CF6), // Dark purple
                              Color(0xFF6D28D9), // Very dark purple
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.colorPrimaryDark
                                  .withValues(alpha: 0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -10,
                              bottom: -20,
                              child: Opacity(
                                opacity: 0.9,
                                child: Image.asset(
                                  'assets/images/icon/billetera.png',
                                  width: 110,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Ganancias disponibles',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.remove_red_eye_outlined,
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        size: 20),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _loading
                                    ? Container(
                                        height: 40,
                                        width: 170,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      )
                                    : Text(
                                        'Bs ${total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                const SizedBox(height: 4),
                                Text(
                                  'Importe de trabajos completados',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(
                                      total > 0
                                          ? Icons.trending_up
                                          : Icons.remove,
                                      color: total > 0
                                          ? const Color(0xFFBBF7D0)
                                          : Colors.white.withValues(alpha: 0.7),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Los importes no confirman el cobro',
                                      style: TextStyle(
                                        color: total > 0
                                            ? const Color(0xFFBBF7D0)
                                            : Colors.white
                                                .withValues(alpha: 0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.chevron_right,
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            if (_hasNonCashEarnings) ...[
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.download_rounded,
                                  label: 'Información',
                                  color: AppTheme.colorPrimary,
                                  textColor: Colors.white,
                                  onTap: () => ToastService.show(
                                      title: 'Importes de trabajos',
                                      body:
                                          'Estos importes no son un saldo retirable. Consulta el estado del pago con tu cliente.',
                                      type: ToastType.info),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.receipt_long_rounded,
                                label: 'Historial',
                                color: Colors.white,
                                textColor: AppTheme.colorText,
                                onTap: _showHistoryModal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.bar_chart_rounded,
                                label: 'Estadísticas',
                                color: Colors.white,
                                textColor: AppTheme.colorText,
                                onTap: _showStatsModal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Filter Dropdown
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: _showFilterMenu,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.colorText
                                      .withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    color: AppTheme.colorMuted, size: 18),
                                const SizedBox(width: 12),
                                Text(
                                  _filter.label,
                                  style: const TextStyle(
                                      color: AppTheme.colorText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                                const Spacer(),
                                const Icon(Icons.keyboard_arrow_down,
                                    color: AppTheme.colorMuted, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_error != null && !_loading && total > 0)
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.colorError.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.colorError
                                    .withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppTheme.colorWarning, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: AppTheme.colorText, fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Reintentar',
                                    style: TextStyle(
                                        color: AppTheme.colorPrimary,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),

                      if (_error != null && !_loading && total == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.colorError
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.cloud_off_rounded,
                                      color: AppTheme.colorError, size: 40),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Error al cargar billetera',
                                  style: TextStyle(
                                    color: AppTheme.colorText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.colorText
                                        .withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ChambaSecondaryButton(
                                  label: 'Reintentar',
                                  icon: Icons.refresh,
                                  onPressed: _load,
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (!_loading && total == 0 && filtered.isEmpty)
                        _buildEmptyState()
                      else if (!_loading && filtered.isNotEmpty) ...[
                        _buildSummary(filtered),
                        const SizedBox(height: 24),
                        _buildRecentActivity(filtered),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: color == Colors.white
              ? const BorderSide(color: AppTheme.colorGlassBorder)
              : BorderSide.none),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: textColor, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final jobs = _filteredJobs;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      const Text(
                        'Historial de Trabajos',
                        style: TextStyle(
                          color: AppTheme.colorText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: AppTheme.colorMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: jobs.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay trabajos en este período',
                            style: TextStyle(color: AppTheme.colorMuted),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: jobs.length,
                          itemBuilder: (context, i) {
                            final job = jobs[i];
                            final isNonCash = job.isNonCashPayment;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.colorSurfaceSoft,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppTheme.colorText
                                        .withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _categoryColor(job.category)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_categoryIcon(job.category),
                                        color: _categoryColor(job.category)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          job.title,
                                          style: const TextStyle(
                                            color: AppTheme.colorText,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              _formatDate(job.completedAt ??
                                                  job.acceptedAt),
                                              style: TextStyle(
                                                  color: AppTheme.colorText
                                                      .withValues(alpha: 0.5),
                                                  fontSize: 12),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isNonCash
                                                    ? AppTheme.colorPrimary
                                                        .withValues(alpha: 0.2)
                                                    : AppTheme.colorSuccess
                                                        .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isNonCash
                                                    ? 'Tarjeta/Digital'
                                                    : 'Efectivo',
                                                style: TextStyle(
                                                  color: isNonCash
                                                      ? AppTheme.colorPrimary
                                                      : AppTheme.colorSuccess,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Bs ${job.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: AppTheme.colorSuccess,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStatsModal() {
    final jobs = _filteredJobs;
    final totalJobs = jobs.length;
    final totalEarned = _totalEarnings;
    final avgPerJob = totalJobs > 0 ? totalEarned / totalJobs : 0.0;

    final nonCashJobs = jobs.where((j) => j.isNonCashPayment).toList();
    final nonCashTotal = nonCashJobs.fold(0.0, (sum, j) => sum + j.amount);
    final cashTotal = totalEarned - nonCashTotal;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Estadísticas de Ingresos',
                      style: TextStyle(
                        color: AppTheme.colorText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.colorMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.colorSurfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text('Trabajos',
                                style: TextStyle(
                                    color: AppTheme.colorMuted, fontSize: 13)),
                            const SizedBox(height: 8),
                            Text('$totalJobs',
                                style: const TextStyle(
                                    color: AppTheme.colorText,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.colorSurfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text('Promedio',
                                style: TextStyle(
                                    color: AppTheme.colorMuted, fontSize: 13)),
                            const SizedBox(height: 8),
                            Text('Bs ${avgPerJob.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppTheme.colorPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Desglose por método de pago',
                  style: TextStyle(
                      color: AppTheme.colorText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.colorSurfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.money,
                              color: AppTheme.colorSuccess, size: 20),
                          const SizedBox(width: 10),
                          const Text('Efectivo',
                              style: TextStyle(
                                  color: AppTheme.colorText,
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text('Bs ${cashTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppTheme.colorText,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                            color: AppTheme.colorGlassBorderSoft, height: 1),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.credit_card,
                              color: AppTheme.colorPrimary, size: 20),
                          const SizedBox(width: 10),
                          const Text('Tarjeta / Digital',
                              style: TextStyle(
                                  color: AppTheme.colorText,
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text('Bs ${nonCashTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppTheme.colorText,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummary(List<WorkerJob> jobs) {
    final knownTimes =
        jobs.where((job) => job.workElapsedSeconds != null).toList();
    final seconds =
        knownTimes.fold<int>(0, (sum, job) => sum + job.workElapsedSeconds!);
    final durationLabel = knownTimes.isEmpty
        ? '—'
        : '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    int totalJobs = jobs.length;
    double avg = totalJobs > 0
        ? jobs.fold(0.0, (sum, j) => sum + j.amount) / totalJobs
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen',
              style: TextStyle(
                  color: AppTheme.colorText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.colorText.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryItem(Icons.work, '$totalJobs', 'Trabajos',
                    AppTheme.colorPrimary),
                Container(
                    width: 1,
                    height: 40,
                    color: AppTheme.colorText.withValues(alpha: 0.1)),
                _buildSummaryItem(
                    Icons.attach_money,
                    'Bs ${avg.toStringAsFixed(2)}',
                    'Promedio',
                    AppTheme.colorPrimary),
                Container(
                    width: 1,
                    height: 40,
                    color: AppTheme.colorText.withValues(alpha: 0.1)),
                _buildSummaryItem(Icons.access_time_filled, durationLabel,
                    'Horas registradas', AppTheme.colorPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 12),
        Text(value,
            style: const TextStyle(
                color: AppTheme.colorText,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: AppTheme.colorText.withValues(alpha: 0.5),
                fontSize: 12)),
      ],
    );
  }

  Widget _buildRecentActivity(List<WorkerJob> jobs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Actividad reciente',
                  style: TextStyle(
                      color: AppTheme.colorText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text('Ver todo',
                  style: TextStyle(
                      color: AppTheme.colorPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.colorText.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: jobs.take(3).map((job) {
                final isLast = job == jobs.take(3).last;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _categoryColor(job.category)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_categoryIcon(job.category),
                            color: _categoryColor(job.category)),
                      ),
                      title: Text(job.title,
                          style: const TextStyle(
                              color: AppTheme.colorText,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          _formatDate(job.completedAt ?? job.acceptedAt),
                          style: TextStyle(
                              color: AppTheme.colorText.withValues(alpha: 0.5),
                              fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Bs ${job.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppTheme.colorSuccess,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              color: AppTheme.colorText.withValues(alpha: 0.3),
                              size: 16),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                          height: 1,
                          color: AppTheme.colorText.withValues(alpha: 0.05),
                          indent: 70,
                          endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.colorText.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.auto_awesome,
                    color: AppTheme.colorPrimary.withValues(alpha: 0.2),
                    size: 100),
                Image.asset('assets/images/icon/billetera.png', width: 80),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Todavía no tienes ganancias',
              style: TextStyle(
                  color: AppTheme.colorText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Acepta tu primer trabajo y\ncomienza a generar ingresos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.colorText.withValues(alpha: 0.6),
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onFindJobs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colorPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Buscar trabajos',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
