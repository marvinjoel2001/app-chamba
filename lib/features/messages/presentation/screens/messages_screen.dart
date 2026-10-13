import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_visuals.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../history/presentation/screens/job_history_details_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../notifications/domain/models/app_notification.dart';
import '../../../notifications/presentation/notification_style.dart';
import '../../../request/presentation/screens/job_in_progress_screen.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import '../../domain/entities/chat_thread.dart';
import '../state/messages_dependencies.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen(
      {this.isActive = true,
      this.loadThreads,
      this.previewNotifications,
      super.key});
  final bool isActive;
  final Future<List<ChatThread>> Function()? loadThreads;
  final List<AppNotification>? previewNotifications;
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  final _realtime = RealtimeService.instance;
  List<ChatThread> _threads = [];
  bool _loading = true, _fetching = false, _again = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtime.connect(userId: SessionStore.currentUser?.id);
    for (final event in [
      'message.new',
      'offer.accepted',
      'job.completed',
      'job.cancelled'
    ]) {
      _realtime.on(event, _onEvent);
    }
    _realtime.reconnectCount.addListener(_reload);
    _load();
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final event in [
      'message.new',
      'offer.accepted',
      'job.completed',
      'job.cancelled'
    ]) {
      _realtime.off(event, _onEvent);
    }
    _realtime.reconnectCount.removeListener(_reload);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _onEvent(dynamic _) => _reload();
  void _reload() {
    if (widget.isActive) unawaited(_load());
  }

  Future<void> _load() async {
    if (_fetching) {
      _again = true;
      return;
    }
    final userId = SessionStore.currentUser?.id;
    if (userId == null) return;
    _fetching = true;
    try {
      final threads = widget.loadThreads != null
          ? await widget.loadThreads!()
          : (await MessagesDependencies.getActiveThreads(userId: userId)).fold(
              onSuccess: (value) => value,
              onFailure: (failure) => throw Exception(failure.message));
      if (!mounted || SessionStore.currentUser?.id != userId) return;
      setState(() {
        _threads = threads.toList()
          ..sort((a, b) => (b.lastMessageAt ?? b.createdAt ?? DateTime(0))
              .compareTo(a.lastMessageAt ?? a.createdAt ?? DateTime(0)));
        _error = null;
        _loading = false;
      });
      if (widget.loadThreads == null) {
        unawaited(UnreadMessagesNotifier.instance.refresh());
      }
    } catch (_) {
      if (mounted && SessionStore.currentUser?.id == userId) {
        setState(() {
          _error = 'No pudimos actualizar las conversaciones.';
          _loading = false;
        });
      }
    } finally {
      _fetching = false;
      if (_again) {
        _again = false;
        if (mounted && widget.isActive) unawaited(_load());
      }
    }
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
          'profilePhotoUrl': thread.counterpartProfilePhotoUrl,
        },
      });
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => NotificationsScreen(
        isActive: widget.isActive,
        previewItems: widget.previewNotifications,
        onRefreshHeader: _load,
        header: MessagesInbox(
          threads: _threads,
          notifications: const [],
          loading: _loading,
          error: _error,
          onRefresh: _load,
          onNotification: (_) {},
          onThread: _openThread,
        ).conversations,
      );
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

  /// Shared conversation section inside the visual notification center.
  Widget get conversations {
    final confirmed = threads.where((thread) => thread.chatEnabled).toList();
    final active = confirmed.where((thread) => thread.isActive).toList();
    final archived = confirmed.where((thread) => !thread.isActive).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (error != null)
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, style: const TextStyle(color: _muted))),
      if (loading && threads.isEmpty) const SkeletonListTile(lines: 2),
      if (active.isNotEmpty) ...[
        const _SectionLabel('Trabajos en curso'),
        ...active.map(_threadTile),
      ],
      if (archived.isNotEmpty)
        ExpansionTile(
          title: const Text('Historial de trabajos'),
          subtitle: Text('${archived.length} conversaciones conservadas'),
          children: archived.map(_threadTile).toList(),
        ),
    ]);
  }

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
                                    padding:
                                        const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
                          if (!loading &&
                              notifications.isEmpty &&
                              active.isEmpty)
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
