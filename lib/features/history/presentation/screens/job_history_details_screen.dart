import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import 'package:intl/intl.dart';

class JobHistoryDetailsScreen extends StatelessWidget {
  const JobHistoryDetailsScreen({
    super.key,
    required this.job,
    required this.isClient,
  });

  final Map<String, dynamic> job;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final photoUrl = job['photoUrl'] as String?;
    final title = job['title'] as String? ?? 'Trabajo';
    final description = job['description'] as String? ?? 'Sin descripción';
    final address = job['address'] as String? ?? 'Ubicación no especificada';
    final category = job['category'] as String? ?? 'General';
    final requestStatus = job['requestStatus'] as String? ?? '';
    final amount = job['amount'] != null ? NumberFormat.currency(symbol: '\$').format(job['amount']) : 'N/A';

    final isCompleted = requestStatus == 'completed';
    final isCancelled = requestStatus == 'cancelled';
    
    Color statusColor = AppTheme.colorPrimary;
    String statusText = 'Asignado';
    if (isCompleted) {
      statusColor = AppTheme.colorSuccess;
      statusText = 'Completado';
    } else if (isCancelled) {
      statusColor = AppTheme.colorError;
      statusText = 'Cancelado';
    }

    final rawDate = isClient ? job['createdAt'] : job['acceptedAt'];
    String formattedDate = '';
    if (rawDate != null) {
      try {
        final date = DateTime.parse(rawDate).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy • HH:mm').format(date);
      } catch (_) {}
    }

    final otherUser = isClient ? job['worker'] : job['client'];
    final otherName = otherUser != null ? '${otherUser['firstName']} ${otherUser['lastName']}'.trim() : 'Sin asignar';
    final otherPhoto = otherUser?['profilePhotoUrl'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del Trabajo'),
      ),
      body: ChambaBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Foto del trabajo
              if (photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    photoUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppTheme.colorPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(Icons.work_outline, size: 64, color: AppTheme.colorPrimary),
                  ),
                ),
              const SizedBox(height: 24),

              // Status Badge
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.colorHighlight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.colorMuted),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: AppTheme.colorMuted),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Profile of Client/Worker
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: otherPhoto != null ? NetworkImage(otherPhoto) : null,
                      backgroundColor: AppTheme.colorPrimary.withOpacity(0.2),
                      child: otherPhoto == null
                          ? Text(
                              otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isClient ? 'Trabajador' : 'Cliente',
                            style: const TextStyle(fontSize: 12, color: AppTheme.colorMuted),
                          ),
                          Text(
                            otherName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Description
              const Text(
                'Descripción',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  description,
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),

              // Details (Category, Address)
              const Text(
                'Detalles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.category, 'Categoría', category),
                    const Divider(color: AppTheme.colorGlassBorderSoft, height: 24),
                    _buildDetailRow(Icons.location_on, 'Ubicación', address),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.colorPrimaryLight),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppTheme.colorMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
