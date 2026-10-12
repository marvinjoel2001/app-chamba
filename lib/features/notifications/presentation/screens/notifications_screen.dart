import 'package:flutter/material.dart';

import '../../../../core/push/notification_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../data/notifications_service.dart';
import '../../domain/models/app_notification.dart';
import '../notification_style.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.previewItems});

  /// Solo para vistas de diseño/tests: muestra estos avisos sin llamar a la API.
  @visibleForTesting
  final List<AppNotification>? previewItems;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final preview = widget.previewItems;
    if (preview != null) {
      _notifications = preview;
      _hasMore = false;
      _isLoading = false;
      return;
    }
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
    });

    try {
      final result = await NotificationsService.getNotifications(
        page: _currentPage,
        limit: 20,
      );

      if (!mounted) return;
      setState(() {
        _notifications = result.items;
        _hasMore = result.hasMore;
        _isLoading = false;
        _error = null;
      });

      // Marcar como leídas
      await _markPageRead(result.items);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus notificaciones. Revisa tu conexión.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      final result = await NotificationsService.getNotifications(
        page: _currentPage,
        limit: 20,
      );

      if (!mounted) return;
      setState(() {
        _notifications.addAll(result.items);
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
      await _markPageRead(result.items);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentPage--;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _markPageRead(List<AppNotification> items) async {
    try {
      await NotificationsService.markAsRead(ids: items.map((n) => n.id).toList());
    } catch (_) {
      // Keep the loaded page and the server's unread count on a network failure.
    }
  }

  /// Lista plana con encabezados de día intercalados ("Hoy", "Ayer", …).
  List<Object> _groupedItems() {
    final items = <Object>[];
    DateTime? lastDay;
    for (final n in _notifications) {
      if (lastDay == null || !isSameLocalDay(lastDay, n.createdAt)) {
        items.add(dayHeaderLabel(n.createdAt));
        lastDay = n.createdAt;
      }
      items.add(n);
    }
    return items;
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SkeletonList(count: 7, lines: 3, circleLeading: false);
    }
    if (_error != null && _notifications.isEmpty) {
      return Center(
        child: ChambaEmptyState(
          icon: Icons.cloud_off_rounded,
          color: AppTheme.colorMuted,
          title: 'Sin conexión',
          message: _error,
          actionLabel: 'Reintentar',
          actionIcon: Icons.refresh_rounded,
          onAction: _loadNotifications,
        ),
      );
    }
    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            ChambaEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Estás al día',
              message: 'Aquí verás las ofertas, cambios de estado y '
                  'mensajes importantes de tus trabajos.',
            ),
          ],
        ),
      );
    }

    final items = _groupedItems();
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return const SkeletonListTile(lines: 3, circleLeading: false);
          }
          final item = items[index];
          if (item is String) return _DayHeader(item);
          return _NotificationCard(
            notification: item as AppNotification,
            onTap: () => NotificationRouter.openFromData(
              {'type': item.type, ...?item.data},
              fromNotificationCenter: true,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      appBar: AppBar(title: const Text('Notificaciones')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey('$_isLoading-${_error != null}-${_notifications.isEmpty}'),
          child: _buildBody(),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.colorMuted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: unread ? const Color(0xFFFBF9FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unread
                    ? AppTheme.colorPrimary.withValues(alpha: 0.22)
                    : AppTheme.colorGlassBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NotificationIcon(type: notification.type, unread: unread),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: AppTheme.colorText,
                          fontSize: 14,
                          height: 1.3,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      if (notification.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: const TextStyle(
                            color: AppTheme.colorMuted,
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: AppTheme.colorMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateTimeLabel(notification.createdAt),
                            style: const TextStyle(
                              color: AppTheme.colorMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
