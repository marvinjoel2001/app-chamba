import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
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
  const WalletScreen({this.getWorkerHistoryUseCase, super.key});

  final GetWorkerHistoryUseCase? getWorkerHistoryUseCase;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with RouteAware {
  GetWorkerHistoryUseCase get _getWorkerHistoryUseCase =>
      widget.getWorkerHistoryUseCase ?? WorkerDependencies.getWorkerHistory;

  bool _loading = true;
  bool _isOffline = false;
  bool _shouldRedirectToLogin = false;
  String? _error;
  List<WorkerJob> _allJobs = const [];
  _DateFilter _filter = _DateFilter.thisWeek;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      // Suscripción a cambios de ruta para recargar al volver a la pantalla
      modalRoute.addScopedWillPopCallback(() async {
        _load();
        return true;
      });
    }
  }

  @override
  void didUpdateWidget(covariant WalletScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recargar datos cuando el widget se actualiza
    _load();
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesión expirada';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _getWorkerHistoryUseCase(workerUserId: user.id);
    result.fold(
      onSuccess: (jobs) {
        if (!mounted) {
          return;
        }
        setState(() {
          _allJobs = jobs;
          _isOffline = false;
          _shouldRedirectToLogin = false;
          _loading = false;
        });
      },
      onFailure: (failure) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = failure.message;
          _isOffline = failure is NetworkFailure;
          _shouldRedirectToLogin = failure is UnauthorizedFailure;
          _loading = false;
        });
      },
    );
  }

  /// Filtra los trabajos según el período seleccionado (solo completados)
  List<WorkerJob> get _filteredJobs {
    // Solo mostrar trabajos completados en la billetera
    final completed = _allJobs.where((job) => job.isCompleted).toList();

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
          (job) => job.acceptedAt != null && job.acceptedAt!.isAfter(cutoff),
        )
        .toList();
  }

  double get _totalEarnings {
    return _filteredJobs.fold(0.0, (sum, job) => sum + job.amount);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    try {
      final dt = value.toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final jobDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(jobDay).inDays;

      final timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      if (diff == 0) return 'Hoy, $timeStr';
      if (diff == 1) return 'Ayer, $timeStr';
      return '${dt.day}/${dt.month}/${dt.year}, $timeStr';
    } catch (_) {
      return '--';
    }
  }

  IconData _categoryIcon(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('plom')) return Icons.plumbing;
    if (c.contains('elec')) return Icons.electrical_services;
    if (c.contains('pint')) return Icons.format_paint;
    if (c.contains('limpie')) return Icons.cleaning_services;
    if (c.contains('carp')) return Icons.carpenter;
    if (c.contains('jard')) return Icons.yard;
    if (c.contains('transport') || c.contains('entrega')) return Icons.local_shipping;
    if (c.contains('mecán') || c.contains('mecan')) return Icons.build;
    if (c.contains('construc')) return Icons.construction;
    return Icons.handyman;
  }

  Color _categoryColor(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('limpie')) return const Color(0xFFB388FF); // Purple Accent
    if (c.contains('entrega') || c.contains('transport')) return const Color(0xFFFFB74D); // Orange
    if (c.contains('elec')) return const Color(0xFF64B5F6); // Blue
    return const Color(0xFF4DB6AC); // Teal
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111C30),
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
                    color: _filter == f ? const Color(0xFF651FFF) : Colors.white,
                    fontWeight: _filter == f ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: _filter == f ? const Icon(Icons.check, color: Color(0xFF651FFF)) : null,
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
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF651FFF),
                backgroundColor: const Color(0xFF111C30),
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
                              Color(0xFF3B1F70), // Dark purple
                              Color(0xFF1E103C), // Very dark purple
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5E35B1).withOpacity(0.2),
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
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.remove_red_eye_outlined, color: Colors.white.withOpacity(0.7), size: 20),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _loading
                                    ? const SizedBox(
                                        height: 40,
                                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                                      )
                                    : Text(
                                        'Bs ${total.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                const SizedBox(height: 4),
                                Text(
                                  'Disponible para retirar',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(
                                      total > 0 ? Icons.trending_up : Icons.remove,
                                      color: total > 0 ? const Color(0xFF00E676) : Colors.white.withOpacity(0.5),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      total > 0 ? '+18% vs. semana pasada' : '— 0% vs. semana pasada',
                                      style: TextStyle(
                                        color: total > 0 ? const Color(0xFF00E676) : Colors.white.withOpacity(0.5),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5), size: 18),
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
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.download_rounded,
                                label: 'Retirar',
                                color: const Color(0xFF651FFF),
                                textColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.receipt_long_rounded,
                                label: 'Historial',
                                color: const Color(0xFF1E2336),
                                textColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.bar_chart_rounded,
                                label: 'Estadísticas',
                                color: const Color(0xFF1E2336),
                                textColor: Colors.white,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111C30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 18),
                                const SizedBox(width: 12),
                                Text(
                                  _filter.label,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                const Spacer(),
                                const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_error != null && !_loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppTheme.colorError),
                            ),
                          ),
                        ),

                      if (!_loading && total == 0 && filtered.isEmpty)
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

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<WorkerJob> jobs) {
    int totalJobs = jobs.length;
    double avg = totalJobs > 0 ? jobs.fold(0.0, (sum, j) => sum + j.amount) / totalJobs : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF111C30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryItem(Icons.work, '$totalJobs', 'Trabajos', const Color(0xFFB388FF)),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                _buildSummaryItem(Icons.attach_money, 'Bs ${avg.toStringAsFixed(0)}', 'Promedio', const Color(0xFFB388FF)),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                _buildSummaryItem(Icons.access_time_filled, '23h 45m', 'Horas', const Color(0xFFB388FF)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
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
              const Text('Actividad reciente', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Ver todo', style: TextStyle(color: const Color(0xFFB388FF), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111C30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: jobs.take(3).map((job) {
                final isLast = job == jobs.take(3).last;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _categoryColor(job.category).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_categoryIcon(job.category), color: _categoryColor(job.category)),
                      ),
                      title: Text(job.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_formatDate(job.acceptedAt), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Bs ${job.amount.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 16),
                        ],
                      ),
                    ),
                    if (!isLast) Divider(height: 1, color: Colors.white.withOpacity(0.05), indent: 70, endIndent: 16),
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
          color: const Color(0xFF111C30),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.auto_awesome, color: const Color(0xFFB388FF).withOpacity(0.2), size: 100),
                Image.asset('assets/images/icon/billetera.png', width: 80),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Todavía no tienes ganancias',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Acepta tu primer trabajo y\ncomienza a generar ingresos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Usually goes to explore or radar screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF651FFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Buscar trabajos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
