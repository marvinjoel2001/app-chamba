import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../messages/domain/entities/chat_thread.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../../review/presentation/screens/rating_screen.dart';

class JobHistoryDetailsScreen extends StatelessWidget {
  const JobHistoryDetailsScreen({
    super.key,
    required this.job,
    required this.isClient,
    this.customRequestId,
  });

  final Map<String, dynamic> job;
  final bool isClient;
  final String? customRequestId;

  @override
  Widget build(BuildContext context) {
    final photoUrl = job['photoUrl'] as String?;
    final title = (job['title'] as String?)?.trim() ?? 'Trabajo';
    final description =
        (job['description'] as String?)?.trim() ?? 'Sin descripción';
    final address =
        (job['address'] as String?)?.trim() ?? 'Ubicación no especificada';
    final category = (job['category'] as String?)?.trim() ?? 'General';
    final requestStatus =
        (job['requestStatus'] as String?)?.toLowerCase().trim() ?? '';
    final amount = job['amount'] != null
        ? NumberFormat.currency(symbol: 'Bs ').format(job['amount'])
        : 'N/A';

    final isCompleted = requestStatus == 'completed';
    final isCancelled = requestStatus == 'cancelled';

    // Status colors, icons and texts
    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;
    String statusText;

    if (isCompleted) {
      statusBgColor = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF16A34A);
      statusIcon = Icons.check_circle_rounded;
      statusText = 'COMPLETADO';
    } else if (isCancelled) {
      statusBgColor = const Color(0xFFFEE2E2);
      statusTextColor = const Color(0xFFDC2626);
      statusIcon = Icons.cancel_rounded;
      statusText = 'CANCELADO';
    } else if (requestStatus == 'in_progress') {
      statusBgColor = const Color(0xFFDBEAFE);
      statusTextColor = const Color(0xFF2563EB);
      statusIcon = Icons.play_circle_rounded;
      statusText = 'EN CURSO';
    } else {
      statusBgColor = const Color(0xFFFEF3C7);
      statusTextColor = const Color(0xFFD97706);
      statusIcon = Icons.schedule_rounded;
      statusText = 'ASIGNADO';
    }

    // Subtitle under the title (e.g. "POR DIA. No servicio real.")
    String subtitle = '';
    if (job['modality'] != null &&
        job['modality'].toString().trim().isNotEmpty) {
      final modality = job['modality'].toString().trim();
      subtitle = const {
            'hourly': 'Por hora',
            'daily': 'Por día',
            'fixed': 'Por trabajo',
          }[modality] ??
          modality;
    } else if (job['subtitle'] != null &&
        job['subtitle'].toString().trim().isNotEmpty) {
      subtitle = job['subtitle'].toString().trim();
    } else if (description.isNotEmpty && description != title) {
      if (description.toLowerCase().startsWith(title.toLowerCase())) {
        subtitle = description.substring(title.length).trim();
      } else {
        final firstLine = description.split('\n').first.trim();
        if (firstLine.isNotEmpty &&
            firstLine != title &&
            firstLine.length <= 60) {
          subtitle = firstLine;
        }
      }
    }
    subtitle = subtitle.replaceFirst(RegExp(r'^[\.\,\-\:\s]+'), '').trim();

    // Date & Time
    final rawDate = job['completedAt'] ??
        job['acceptedAt'] ??
        job['createdAt'] ??
        (isClient ? job['createdAt'] : job['acceptedAt']);
    String formattedDate = '';
    if (rawDate != null) {
      try {
        final date = DateTime.parse(rawDate.toString()).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy • HH:mm').format(date);
      } catch (_) {
        formattedDate = rawDate.toString();
      }
    }

    // Payment status & badge
    final isPaid = job['paymentStatus'] == 'paid' || job['paid'] == true;

    // Counterpart (Worker / Client)
    final otherUser = isClient ? job['worker'] : job['client'];
    final otherName = otherUser != null
        ? '${otherUser['firstName'] ?? ''} ${otherUser['lastName'] ?? ''}'
            .trim()
        : 'Sin asignar';
    final otherPhoto = otherUser?['profilePhotoUrl'] as String?;

    // ID del trabajo
    final resolvedRequestId = customRequestId ??
        job['requestId']?.toString() ??
        job['id']?.toString() ??
        '';
    final rawJobId = job['displayId'] ??
        job['jobCode'] ??
        job['code'] ??
        (resolvedRequestId.isNotEmpty ? resolvedRequestId : null);
    String jobDisplayId = '#N/A';
    if (rawJobId != null) {
      final str = rawJobId.toString().trim();
      if (str.startsWith('#')) {
        jobDisplayId = str;
      } else if (str.length > 12 && str.contains('-')) {
        jobDisplayId = '#${str.split('-').first.toUpperCase()}';
      } else {
        jobDisplayId = '#$str';
      }
    }

    // Chat availability
    final hasThread = job['threadId'] != null &&
        job['threadId'].toString().trim().isNotEmpty &&
        job['threadId'].toString() != 'null';
    final canChat = hasThread &&
        [
          'accepted',
          'assigned',
          'in_progress',
          'completed',
          'cancelled'
        ].contains(requestStatus.isEmpty ? job['offerStatus'] : requestStatus);

    // Rating eligibility (Client when completed)
    final canRate = isClient && (isCompleted || requestStatus == 'completed');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Detalles del Trabajo',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            elevation: 4,
            onSelected: (value) {
              if (value == 'chat') {
                _openChat(
                  context,
                  title: title,
                  otherName: otherName,
                  isCompleted: isCompleted,
                  isCancelled: isCancelled,
                );
              } else if (value == 'rate') {
                _openRating(context, resolvedRequestId);
              } else if (value == 'info') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ID del trabajo: $jobDisplayId'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              if (canChat)
                const PopupMenuItem(
                  value: 'chat',
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 18, color: Color(0xFF7C3AED)),
                      SizedBox(width: 10),
                      Text(
                        'Ver conversación',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              if (canRate)
                const PopupMenuItem(
                  value: 'rate',
                  child: Row(
                    children: [
                      Icon(Icons.star_outline_rounded,
                          size: 18, color: Color(0xFF16A34A)),
                      SizedBox(width: 10),
                      Text(
                        'Calificar trabajo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 10),
                    Text(
                      'Información',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Tarjeta Resumen / Encabezado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (photoUrl != null && photoUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        photoUrl,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildIconContainer(
                          icon: Icons.work_outline_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFFF3E8FF),
                          size: 58,
                          iconSize: 28,
                        ),
                      ),
                    )
                  else
                    _buildIconContainer(
                      icon: Icons.work_outline_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF3E8FF),
                      size: 58,
                      iconSize: 28,
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon,
                                  size: 13, color: statusTextColor),
                              const SizedBox(width: 5),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusTextColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Fecha y hora
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  _buildIconContainer(
                    icon: Icons.calendar_today_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF3E8FF),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fecha y hora',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate.isNotEmpty
                            ? formattedDate
                            : 'Fecha no especificada',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Monto
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  _buildIconContainer(
                    icon: Icons.attach_money_rounded,
                    iconColor: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFDCFCE7),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monto',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        amount,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? const Color(0xFFDCFCE7)
                          : isCancelled
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaid
                              ? Icons.check_circle_rounded
                              : isCancelled
                                  ? Icons.cancel_rounded
                                  : Icons.schedule_rounded,
                          size: 14,
                          color: isPaid
                              ? const Color(0xFF16A34A)
                              : isCancelled
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPaid
                              ? 'Pagado'
                              : isCancelled
                                  ? 'Cancelado'
                                  : 'Sin confirmar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isPaid
                                ? const Color(0xFF16A34A)
                                : isCancelled
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Trabajador / Cliente
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: canChat
                  ? () => _openChat(
                        context,
                        title: title,
                        otherName: otherName,
                        isCompleted: isCompleted,
                        isCancelled: isCancelled,
                      )
                  : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    if (otherPhoto != null && otherPhoto.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          otherPhoto,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildIconContainer(
                            icon: Icons.person_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            bgColor: const Color(0xFFF3E8FF),
                          ),
                        ),
                      )
                    else
                      _buildIconContainer(
                        icon: Icons.person_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF3E8FF),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isClient ? 'Trabajador' : 'Cliente',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            otherName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 5. Descripción
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildIconContainer(
                        icon: Icons.description_outlined,
                        iconColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFE0F2FE),
                        size: 38,
                        iconSize: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Descripción',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                      ),
                    ),
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 6. Sección: Detalles
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 10, left: 4),
              child: Text(
                'Detalles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),

            // 7. Tarjeta con detalles agrupados
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _buildDetailItem(
                    icon: Icons.widgets_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFF3E8FF),
                    label: 'Categoría',
                    value: category,
                  ),
                  const Divider(
                      height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
                  _buildDetailItem(
                    icon: Icons.location_on_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFDBEAFE),
                    label: 'Ubicación',
                    value: address,
                  ),
                  const Divider(
                      height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
                  _buildDetailItem(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFF64748B),
                    iconBg: const Color(0xFFF1F5F9),
                    label: 'ID del trabajo',
                    value: jobDisplayId,
                  ),
                  const Divider(
                      height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildIconContainer(
                        icon: Icons.access_time_filled_rounded,
                        iconColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFEF3C7),
                        size: 36,
                        iconSize: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estado',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon,
                                      size: 12, color: statusTextColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText[0].toUpperCase() +
                                        statusText.substring(1).toLowerCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: statusTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 8. Botón principal de acción
            if (canRate)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _openRating(context, resolvedRequestId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Calificar trabajo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (canChat)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _openChat(
                    context,
                    title: title,
                    otherName: otherName,
                    isCompleted: isCompleted,
                    isCancelled: isCancelled,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCompleted || isCancelled
                            ? Icons.history_rounded
                            : Icons.chat_bubble_outline_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCompleted || isCancelled
                            ? 'Ver conversación del trabajo'
                            : 'Coordinar trabajo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (canRate && canChat) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _openChat(
                    context,
                    title: title,
                    otherName: otherName,
                    isCompleted: isCompleted,
                    isCancelled: isCancelled,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Ver conversación del trabajo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openChat(
    BuildContext context, {
    required String title,
    required String otherName,
    required bool isCompleted,
    required bool isCancelled,
  }) {
    if (job['threadId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay una conversación activa para este trabajo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          threadId: job['threadId'].toString(),
          jobId: job['requestId']?.toString() ?? customRequestId ?? '',
          jobTitle: title,
          counterpartName: otherName,
          isArchived: isCompleted || isCancelled,
          jobStatus: isCompleted
              ? ChatThreadStatus.completed
              : isCancelled
                  ? ChatThreadStatus.cancelled
                  : ChatThreadStatus.active,
        ),
      ),
    );
  }

  void _openRating(BuildContext context, String resolvedRequestId) {
    if (resolvedRequestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el ID del trabajo para calificar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RatingScreen(requestId: resolvedRequestId),
      ),
    );
  }

  static BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static Widget _buildIconContainer({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    double size = 44,
    double iconSize = 22,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }

  static Widget _buildDetailItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconContainer(
          icon: icon,
          iconColor: iconColor,
          bgColor: iconBg,
          size: 36,
          iconSize: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
