import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../data/notifications_service.dart';
import '../../domain/models/app_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      _currentPage = 1;
    });

    final result = await NotificationsService.getNotifications(
      page: _currentPage,
      limit: 20,
    );

    if (!mounted) return;
    setState(() {
      _notifications = result.items;
      _hasMore = result.hasMore;
      _isLoading = false;
    });

    // Marcar como leídas
    await NotificationsService.markAsRead();
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

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
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'offer_new':
        return Icons.local_offer;
      case 'offer_accepted':
        return Icons.check_circle;
      case 'request_new':
        return Icons.work;
      case 'worker_arrived':
        return Icons.location_on;
      case 'job_finished':
        return Icons.flag;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'offer_new':
        return AppTheme.colorInfo;
      case 'offer_accepted':
        return AppTheme.colorSuccess;
      case 'request_new':
        return AppTheme.colorWarning;
      case 'worker_arrived':
        return AppTheme.colorPrimary;
      case 'job_finished':
        return Colors.purple;
      default:
        return AppTheme.colorMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Text(
                    'No tienes notificaciones.',
                    style: TextStyle(color: AppTheme.colorMuted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the end
                      if (index == _notifications.length) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final item = _notifications[index];
                      final color = _getColorForType(item.type);

                      return Container(
                        color: item.isRead
                            ? Colors.transparent
                            : AppTheme.colorPrimary.withOpacity(0.1),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            child: Icon(
                              _getIconForType(item.type),
                              color: color,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: item.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: Colors.white,
                                ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.body,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd MMM, HH:mm')
                                      .format(item.createdAt),
                                  style: const TextStyle(
                                    color: AppTheme.colorMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
