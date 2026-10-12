import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/push/notification_router.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/session/unread_notifications_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_visuals.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../history/presentation/screens/job_history_details_screen.dart';
import '../../../notifications/data/notifications_service.dart';
import '../../../notifications/domain/models/app_notification.dart';
import '../../../notifications/presentation/notification_style.dart';
import '../../../request/presentation/screens/job_in_progress_screen.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import '../../domain/entities/chat_thread.dart';
import '../state/messages_dependencies.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({this.isActive = true, super.key});

  /// `true` mientras la pestaña está a la vista: los avisos mostrados se
  /// marcan como leídos (antes lo hacía la pantalla de notificaciones aparte).
  final bool isActive;
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  final _realtime = RealtimeService.instance;
  List<ChatThread> _threads = [];
  List<AppNotification> _notifications = [];
  bool _loading = true, _fetching = false, _again = false;
  bool _hasMore = false, _loadingMore = false;
  int _page = 1;

  /// Avisos que estaban sin leer cuando se mostraron en esta visita: siguen
  /// destacados aunque el servidor ya los tenga como leídos.
  final Set<String> _sessionUnread = {};
  final Set<String> _markingRead = {};

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _markShownAsRead();
    } else if (!widget.isActive && oldWidget.isActive) {
      setState(_sessionUnread.clear);
    }
  }

  void _markShownAsRead() {
    if (!widget.isActive) return;
    final ids = _notifications
        .where((n) => !n.isRead && !_markingRead.contains(n.id))
        .map((n) => n.id)
        .toList();
    if (ids.isEmpty) return;
    _sessionUnread.addAll(ids);
    _markingRead.addAll(ids);
    unawaited(NotificationsService.markAsRead(ids: ids)
        .then((_) => UnreadNotificationsNotifier.instance.refresh())
        .catchError((_) {/* Se reintenta en la próxima carga. */})
        .whenComplete(() => _markingRead.removeAll(ids)));
  }

  List<AppNotification> get _displayedNotifications => [
        for (final n in _notifications)
          n.isRead && _sessionUnread.contains(n.id)
              ? AppNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  type: n.type,
                  isRead: false,
                  createdAt: n.createdAt,
                  data: n.data)
              : n,
      ];
  String? _error, _notificationError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtime.connect(userId: SessionStore.currentUser?.id);
    for (final event in [
      'message.new',
      'notification.new',
      'offer.accepted',
      'job.completed',
      'job.cancelled'
    ]) {
      _realtime.on(event, _onEvent);
    }
    _realtime.reconnectCount.addListener(_reload);
    UnreadNotificationsNotifier.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final event in [
      'message.new',
      'notification.new',
      'offer.accepted',
      'job.completed',
      'job.cancelled'
    ]) {
      _realtime.off(event, _onEvent);
    }
    _realtime.reconnectCount.removeListener(_reload);
    UnreadNotificationsNotifier.instance.removeListener(_reload);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _onEvent(dynamic _) => _reload();
  void _reload() => unawaited(_load());
  Future<void> _load() async {
    if (_fetching) {
      _again = true;
      return;
    }
    final user = SessionStore.currentUser;
    if (user == null) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Inicia sesión para ver tus notificaciones.';
        });
      return;
    }
    _fetching = true;
    await Future.wait([
      _loadThreads(user.id),
      _loadNotifications(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
    _fetching = false;
    _markShownAsRead();
    if (_again) {
      _again = false;
      _reload();
    }
  }

  Future<void> _loadThreads(String userId) async {
    final result = await MessagesDependencies.getActiveThreads(userId: userId);
    if (!mounted) return;
    result.fold(
        onSuccess: (threads) {
          setState(() {
            _threads = threads.toList()
              ..sort((a, b) => (b.lastMessageAt ?? b.createdAt ?? DateTime(0))
                  .compareTo(a.lastMessageAt ?? a.createdAt ?? DateTime(0)));
            _error = null;
          });
          UnreadMessagesNotifier.instance.refresh();
        },
        onFailure: (failure) => setState(() => _error = failure.message));
  }

  static const _pageSize = 20;

  Future<void> _loadNotifications() async {
    try {
      final result =
          await NotificationsService.getNotifications(page: 1, limit: _pageSize);
      if (mounted)
        setState(() {
          _notifications = result.items;
          _hasMore = result.hasMore;
          _page = 1;
          _notificationError = null;
        });
    } catch (_) {
      if (mounted)
        setState(() =>
            _notificationError = 'No pudimos actualizar las notificaciones.');
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_loadingMore || !_hasMore || _fetching) return;
    setState(() => _loadingMore = true);
    try {
      final result = await NotificationsService.getNotifications(
          page: _page + 1, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        final seen = _notifications.map((n) => n.id).toSet();
        _notifications = [
          ..._notifications,
          ...result.items.where((n) => !seen.contains(n.id)),
        ];
        _hasMore = result.hasMore;
        _page++;
      });
      _markShownAsRead();
    } catch (_) {
      // Se reintenta al volver a llegar al final de la lista.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    try {
      await NotificationsService.markAsRead(ids: [notification.id]);
      await UnreadNotificationsNotifier.instance.refresh();
    } catch (_) {/* Keep navigation available when marking read fails. */}
    if (!mounted) return;
    NotificationRouter.openFromData(
        {'type': notification.type, ...?notification.data},
        fromNotificationCenter: true);
  }

  Future<void> _openThread(ChatThread thread) async {
    if (!thread.chatEnabled) return;
    final isWorker = SessionStore.currentUser?.type == 'worker';
    final Widget screen;
    if (thread.isActive) {
      screen = isWorker
          ? JobInProgressScreen(requestId: thread.jobId)
          : TrackingScreen(requestId: thread.jobId);
    } else {
      screen = JobHistoryDetailsScreen(isClient: !isWorker, job: {
        'requestId': thread.jobId,
        'threadId': thread.id,
        'title': thread.jobTitle,
        'description': thread.jobDescription,
        'category': thread.category,
        'amount': thread.agreedPrice,
        'requestStatus': thread.isCompleted ? 'completed' : 'cancelled',
        'offerStatus': 'accepted',
        isWorker ? 'client' : 'worker': {
          'firstName': thread.counterpartFirstName ?? thread.counterpartName,
          'lastName': thread.counterpartLastName ?? '',
          'profilePhotoUrl': thread.counterpartProfilePhotoUrl
        },
      });
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => MessagesInbox(
      threads: _threads,
      notifications: _displayedNotifications,
      loading: _loading,
      error: _error,
      notificationError: _notificationError,
      hasMore: _hasMore,
      loadingMore: _loadingMore,
      onRefresh: _load,
      onLoadMore: _loadMoreNotifications,
      onNotification: _openNotification,
      onThread: _openThread);
}

/// Pestaña "Notificaciones": chats de trabajos en curso arriba y, debajo, todos
/// los avisos agrupados por día (con paginación al hacer scroll). Es el único
/// lugar de la app para ver notificaciones.
class MessagesInbox extends StatelessWidget {
  const MessagesInbox(
      {required this.threads,
      required this.notifications,
      required this.onRefresh,
      required this.onNotification,
      required this.onThread,
      this.onLoadMore,
      this.hasMore = false,
      this.loadingMore = false,
      this.loading = false,
      this.error,
      this.notificationError,
      super.key});
  final List<ChatThread> threads;
  final List<AppNotification> notifications;
  final bool loading, hasMore, loadingMore;
  final String? error, notificationError;
  final Future<void> Function() onRefresh;
  final VoidCallback? onLoadMore;
  final ValueChanged<AppNotification> onNotification;
  final ValueChanged<ChatThread> onThread;
  static const _ink = AppTheme.colorText, _muted = AppTheme.colorMuted;

  /// Avisos con encabezados de día intercalados ("Hoy", "Ayer", …).
  List<Object> _grouped() {
    final items = <Object>[];
    DateTime? lastDay;
    for (final n in notifications) {
      if (lastDay == null || !isSameLocalDay(lastDay, n.createdAt)) {
        items.add(dayHeaderLabel(n.createdAt));
        lastDay = n.createdAt;
      }
      items.add(n);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = threads
        .where((thread) => thread.chatEnabled && thread.jobId.isNotEmpty)
        .toList();
    final active = confirmed.where((thread) => thread.isActive).toList();
    final archived = confirmed.where((thread) => !thread.isActive).toList();
    final grouped = _grouped();
    return Scaffold(
        backgroundColor: AppTheme.colorBackground,
        body: SafeArea(
            child: NotificationListener<ScrollNotification>(
                onNotification: (scroll) {
                  if (hasMore &&
                      !loadingMore &&
                      scroll.metrics.extentAfter < 400) {
                    onLoadMore?.call();
                  }
                  return false;
                },
                child: RefreshIndicator(
                    onRefresh: onRefresh,
                    child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          const SliverToBoxAdapter(
                              child: Padding(
                                  padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Notificaciones',
                                            style: TextStyle(
                                                fontSize: 28,
                                                color: _ink,
                                                fontWeight: FontWeight.w800)),
                                        SizedBox(height: 5),
                                        Text(
                                            'Novedades de tus trabajos y ofertas.',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: _muted,
                                                height: 1.5))
                                      ]))),
                          if (error != null || notificationError != null)
                            SliverToBoxAdapter(
                                child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 8, 20, 0),
                                    child: Text(
                                        [
                                          if (error != null) error!,
                                          if (notificationError != null)
                                            notificationError!
                                        ].join('\n'),
                                        style: const TextStyle(
                                            color: _muted, fontSize: 12)))),
                          if (loading &&
                              threads.isEmpty &&
                              notifications.isEmpty)
                            const SliverToBoxAdapter(
                                child: Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: SkeletonList(
                                        count: 6,
                                        lines: 3,
                                        circleLeading: false,
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero))),
                          if (active.isNotEmpty) ...[
                            const SliverToBoxAdapter(
                                child: _SectionLabel('Trabajos en curso')),
                            SliverList.builder(
                                itemCount: active.length,
                                itemBuilder: (context, index) =>
                                    _threadTile(active[index])),
                          ],
                          if (grouped.isNotEmpty)
                            SliverList.builder(
                                itemCount: grouped.length,
                                itemBuilder: (context, index) {
                                  final item = grouped[index];
                                  return item is String
                                      ? _SectionLabel(item)
                                      : _notificationTile(
                                          item as AppNotification);
                                }),
                          if (loadingMore)
                            const SliverToBoxAdapter(
                                child: SkeletonListTile(
                                    lines: 3, circleLeading: false)),
                          if (!loading && notifications.isEmpty && active.isEmpty)
                            SliverToBoxAdapter(
                                child: Padding(
                                    padding: const EdgeInsets.only(top: 40),
                                    child: ChambaEmptyState(
                                        icon: Icons.notifications_none_rounded,
                                        title: notificationError == null
                                            ? 'Estás al día'
                                            : 'Sin conexión',
                                        message:
                                            'Aquí verás las ofertas, cambios de estado y '
                                            'mensajes importantes de tus trabajos.',
                                        actionLabel: notificationError == null
                                            ? null
                                            : 'Reintentar',
                                        actionIcon: Icons.refresh_rounded,
                                        onAction: notificationError == null
                                            ? null
                                            : () => onRefresh()))),
                          if (archived.isNotEmpty)
                            SliverToBoxAdapter(
                                child: ExpansionTile(
                                    title: const Text('Historial de trabajos',
                                        style: TextStyle(
                                            color: _ink,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                        '${archived.length} conversaciones conservadas',
                                        style: const TextStyle(
                                            color: _muted, fontSize: 12)),
                                    iconColor: AppTheme.colorPrimary,
                                    collapsedIconColor: _muted,
                                    children:
                                        archived.map(_threadTile).toList())),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ])))));
  }

  static bool _isAnnouncement(AppNotification n) =>
      n.type == 'announcement' || n.type == 'broadcast';

  Widget _notificationTile(AppNotification notification) {
    return _tile(
        onTap: () => onNotification(notification),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NotificationIcon(
              type: notification.type, unread: !notification.isRead, size: 42),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(notification.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: notification.isRead
                            ? FontWeight.w600
                            : FontWeight.w700)),
                const SizedBox(height: 4),
                // Los avisos del equipo se leen completos aquí: no llevan a
                // otra pantalla.
                Text(notification.body,
                    maxLines: _isAnnouncement(notification) ? null : 2,
                    overflow: _isAnnouncement(notification)
                        ? null
                        : TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 12, color: _muted),
                  const SizedBox(width: 4),
                  Text(dateTimeLabel(notification.createdAt),
                      style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ]),
              ])),
          const SizedBox(width: 6),
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppTheme.colorPrimaryLight)),
        ]));
  }

  Widget _threadTile(ChatThread thread) => _tile(
      onTap: () => onThread(thread),
      child: Row(children: [
        CategoryIconTile(category: thread.category, size: 46),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(thread.jobTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700))),
            if ((thread.lastMessageAt ?? thread.createdAt) != null) ...[
              const SizedBox(width: 8),
              Text(
                  compactDateTimeLabel(
                      (thread.lastMessageAt ?? thread.createdAt)!),
                  style: TextStyle(
                      color: thread.unreadCount > 0
                          ? AppTheme.colorPrimary
                          : _muted,
                      fontSize: 11,
                      fontWeight: thread.unreadCount > 0
                          ? FontWeight.w700
                          : FontWeight.w500)),
            ],
          ]),
          const SizedBox(height: 4),
          Text('${thread.counterpartName} · ${thread.statusLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
              (thread.lastMessage ?? '').contains('[Foto]')
                  ? 'Foto del trabajo'
                  : thread.lastMessage ?? 'Listo para coordinar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 11))
        ])),
        if (thread.unreadCount > 0)
          Badge(
              label: Text(
                  thread.unreadCount > 99 ? '99+' : '${thread.unreadCount}'),
              backgroundColor: AppTheme.colorPrimary),
        const SizedBox(width: 6),
        Icon(
            thread.isActive
                ? Icons.chevron_right_rounded
                : Icons.lock_outline_rounded,
            size: 18,
            color: AppTheme.colorPrimaryLight),
      ]));
  Widget _tile({required VoidCallback onTap, required Widget child}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.colorGlassBorder)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child:
                  Padding(padding: const EdgeInsets.all(14), child: child))));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(label,
          style: const TextStyle(
              color: AppTheme.colorMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2)));
}
