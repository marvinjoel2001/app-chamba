import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

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
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _allJobs = const [];
  _DateFilter _filter = _DateFilter.thisWeek;

  @override
  void initState() {
    super.initState();
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
    try {
      final response = await MobileBackendService.workerHistory(
        workerUserId: user.id,
      );
      setState(() {
        _allJobs = (response['jobs'] as List<dynamic>? ?? const []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Filtra los trabajos según el período seleccionado (solo completados)
  List<dynamic> get _filteredJobs {
    // Solo mostrar trabajos completados en la billetera
    final completed = _allJobs.where((item) {
      final job = item as Map<String, dynamic>;
      return job['requestStatus']?.toString() == 'completed';
    }).toList();

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

    return completed.where((item) {
      final job = item as Map<String, dynamic>;
      final raw = job['acceptedAt']?.toString();
      if (raw == null) return false;
      try {
        final date = DateTime.parse(raw);
        return date.isAfter(cutoff);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  double get _totalEarnings {
    return _filteredJobs.fold(0.0, (sum, item) {
      final job = item as Map<String, dynamic>;
      return sum + ((job['amount'] as num?)?.toDouble() ?? 0);
    });
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '--';
    try {
      final dt = DateTime.parse(value).toLocal();
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
      return value.length > 16 ? value.substring(0, 16) : value;
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
    if (c.contains('transport')) return Icons.local_shipping;
    if (c.contains('mecán') || c.contains('mecan')) return Icons.build;
    if (c.contains('construc')) return Icons.construction;
    return Icons.handyman;
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
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Billetera',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.colorSuccess,
                      fontWeight: FontWeight.w800,
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

            // ── Card de ganancias totales ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1F14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.colorSuccess.withValues(alpha: 0.25),
                  ),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ganancias totales',
                            style: TextStyle(
                              color: AppTheme.colorMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bs ${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppTheme.colorText,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.trending_up,
                                color: AppTheme.colorSuccess,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${filtered.length} trabajo${filtered.length == 1 ? '' : 's'} en el período',
                                style: const TextStyle(
                                  color: AppTheme.colorSuccess,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Botón retirar fondos (placeholder)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Función de retiro próximamente disponible.',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.account_balance,
                                color: Colors.black,
                                size: 18,
                              ),
                              label: const Text(
                                'Retirar Fondos',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.colorSuccess,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Filtros de fecha ─────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _DateFilter.values.map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.colorSuccess
                              : AppTheme.colorSurfaceSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? AppTheme.colorSuccess
                                : AppTheme.colorGlassBorderSoft,
                          ),
                        ),
                        child: Text(
                          f.label,
                          style: TextStyle(
                            color: selected
                                ? Colors.black
                                : AppTheme.colorMuted,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Lista de trabajos ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Trabajos Completados',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.colorError),
                      ),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.work_off,
                            color: AppTheme.colorMuted,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sin trabajos en este período',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppTheme.colorMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final job = filtered[i] as Map<String, dynamic>;
                        final title = job['title']?.toString() ?? 'Trabajo';
                        final amount = (job['amount'] as num?)?.toDouble() ?? 0;
                        final address = job['address']?.toString() ?? '';
                        final category = job['category']?.toString();
                        final date = _formatDate(job['acceptedAt']?.toString());

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111C30),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.colorGlassBorderSoft,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Ícono de categoría
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.colorSuccess.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _categoryIcon(category),
                                  color: AppTheme.colorSuccess,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: AppTheme.colorText,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (address.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        address,
                                        style: const TextStyle(
                                          color: AppTheme.colorMuted,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          color: AppTheme.colorMuted,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          date,
                                          style: const TextStyle(
                                            color: AppTheme.colorMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Monto
                              Text(
                                '+ Bs ${amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppTheme.colorSuccess,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
