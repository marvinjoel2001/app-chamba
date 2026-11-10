import 'package:flutter/material.dart';

import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../support/presentation/screens/support_screen.dart';

class ClientPaymentsScreen extends StatefulWidget {
  const ClientPaymentsScreen({super.key});

  @override
  State<ClientPaymentsScreen> createState() => _ClientPaymentsScreenState();
}

class _ClientPaymentsScreenState extends State<ClientPaymentsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _payments = [];
  String _selectedFilter = 'all'; // 'all', 'refund_pending', 'refunded', 'paid'

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payments = await MobileBackendService.instance.getClientPayments();
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus pagos. Revisa tu conexión.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPayments {
    if (_selectedFilter == 'all') return _payments;

    return _payments.where((item) {
      final status = (item['status'] as String?)?.toLowerCase().trim() ?? '';
      final requestStatus =
          (item['requestStatus'] as String?)?.toLowerCase().trim() ?? '';
      final isCancelled = requestStatus == 'cancelled';
      final isPendingRefund =
          status == 'refund_pending' || (status == 'paid' && isCancelled);
      final isRefunded = status == 'refunded';
      final isPaid = status == 'paid' && !isCancelled;

      switch (_selectedFilter) {
        case 'refund_pending':
          return isPendingRefund;
        case 'refunded':
          return isRefunded;
        case 'paid':
          return isPaid;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = AppTheme.light();

    return Theme(
      data: lightTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Pagos y reembolsos',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Banner informativo superior
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFEFF6FF),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aquí ves tus pagos realizados por QR o tarjeta dentro de la app. Si un trabajo pagado se cancela, tu reembolso se procesa automáticamente.',
                        style: TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Filtros superiores en chips
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('En reembolso', 'refund_pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Reembolsados', 'refunded'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pagados', 'paid'),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

              // 3. Contenido de pagos
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadPayments,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = value),
      selectedColor: AppTheme.colorPrimary,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF475569),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildBody() {
    if (_loading && _payments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _payments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadPayments,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final list = _filteredPayments;
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _selectedFilter == 'all'
                        ? 'No tienes pagos registrados aún'
                        : 'No hay pagos en esta categoría',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Aquí podrás consultar tus comprobantes y el estado de tus reembolsos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _PaymentCard(item: list[index]),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = (item['requestTitle'] ??
            item['title'] ??
            item['jobTitle'] ??
            'Trabajo')
        .toString()
        .trim();
    final rawDate = item['createdAt'] ?? item['paidAt'] ?? item['date'];
    String formattedDate = '';
    if (rawDate != null) {
      try {
        final d = DateTime.parse(rawDate.toString()).toLocal();
        final day = d.day.toString().padLeft(2, '0');
        final month = d.month.toString().padLeft(2, '0');
        final year = d.year.toString();
        final hour = d.hour.toString().padLeft(2, '0');
        final min = d.minute.toString().padLeft(2, '0');
        formattedDate = '$day/$month/$year • $hour:$min';
      } catch (_) {
        formattedDate = rawDate.toString();
      }
    }

    final method = (item['methodName'] ??
            item['provider'] ??
            item['method'] ??
            'Pago digital')
        .toString()
        .toUpperCase();

    final amountVal = item['amount'] ?? item['paidAmount'];
    String amountFormatted = 'N/A';
    if (amountVal != null) {
      final num? numVal = num.tryParse(amountVal.toString());
      if (numVal != null) {
        amountFormatted = numVal.truncateToDouble() == numVal
            ? 'Bs ${numVal.toInt()}'
            : 'Bs ${numVal.toStringAsFixed(2)}';
      } else {
        amountFormatted = 'Bs $amountVal';
      }
    }

    final status = (item['status'] as String?)?.toLowerCase().trim() ?? '';
    final requestStatus =
        (item['requestStatus'] as String?)?.toLowerCase().trim() ?? '';
    final isCancelled = requestStatus == 'cancelled';

    final isPendingRefund =
        status == 'refund_pending' || (status == 'paid' && isCancelled);
    final isRefunded = status == 'refunded';
    final isRefundDeclined = status == 'refund_declined';

    final refundNote = (item['refundNote'] as String?)?.trim();
    final refundReason = (item['refundReason'] as String?)?.trim() ??
        (item['cancelReason'] as String?)?.trim();

    final rawRefundedAt = item['refundedAt'];
    String formattedRefundDate = '';
    if (rawRefundedAt != null) {
      try {
        final d = DateTime.parse(rawRefundedAt.toString()).toLocal();
        final day = d.day.toString().padLeft(2, '0');
        final month = d.month.toString().padLeft(2, '0');
        final year = d.year.toString();
        final hour = d.hour.toString().padLeft(2, '0');
        final min = d.minute.toString().padLeft(2, '0');
        formattedRefundDate = '$day/$month/$year • $hour:$min';
      } catch (_) {
        formattedRefundDate = rawRefundedAt.toString();
      }
    }

    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;
    String badgeLabel;

    if (isPendingRefund) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFD97706);
      badgeIcon = Icons.currency_exchange_rounded;
      badgeLabel = 'Reembolso en proceso';
    } else if (isRefunded) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF16A34A);
      badgeIcon = Icons.check_circle_rounded;
      badgeLabel = 'Reembolsado';
    } else if (isRefundDeclined) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
      badgeIcon = Icons.cancel_rounded;
      badgeLabel = 'Reembolso rechazado';
    } else {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF16A34A);
      badgeIcon = Icons.check_circle_rounded;
      badgeLabel = 'Pagado';
    }

    final requestId = item['requestId']?.toString() ??
        item['jobId']?.toString() ??
        item['id']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Título y Monto
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                amountFormatted,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Fecha y método
          Row(
            children: [
              if (formattedDate.isNotEmpty) ...[
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  method,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badge de estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 14, color: badgeText),
                const SizedBox(width: 6),
                Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: badgeText,
                  ),
                ),
              ],
            ),
          ),

          // Caja explicativa según estado
          if (isPendingRefund) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estamos procesando la devolución de tu dinero. Te notificaremos apenas se complete.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF92400E),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isRefunded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (formattedRefundDate.isNotEmpty)
                    Text(
                      'Fecha de devolución: $formattedRefundDate',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (refundNote != null && refundNote.isNotEmpty) ...[
                    if (formattedRefundDate.isNotEmpty) const SizedBox(height: 4),
                    Text(
                      'Referencia: $refundNote',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (isRefundDeclined) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                refundNote != null && refundNote.isNotEmpty
                    ? 'Detalle: $refundNote'
                    : 'La solicitud de reembolso no pudo ser procesada.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
          ],

          // Motivo de cancelación o reembolso si existe
          if (refundReason != null && refundReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Motivo: $refundReason',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Botón "¿Tienes dudas? Ir a Soporte"
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SupportScreen(requestId: requestId),
                  ),
                );
              },
              icon: const Icon(
                Icons.support_agent_rounded,
                size: 16,
                color: Color(0xFF4F46E5),
              ),
              label: const Text(
                '¿Tienes dudas? Ir a Soporte',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
