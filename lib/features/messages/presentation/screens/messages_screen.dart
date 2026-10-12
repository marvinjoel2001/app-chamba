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
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../request/presentation/screens/job_in_progress_screen.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import '../../domain/entities/chat_thread.dart';
import '../state/messages_dependencies.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  final _realtime = RealtimeService.instance;
  List<ChatThread> _threads = [];
  List<AppNotification> _notifications = [];
  bool _loading = true, _fetching = false, _again = false;
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
          _error = 'Inicia sesión para ver tus mensajes.';
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

  Future<void> _loadNotifications() async {
    try {
      final result = await NotificationsService.getNotifications(limit: 8);
      if (mounted)
        setState(() {
          _notifications = result.items;
          _notificationError = null;
        });
    } catch (_) {
      if (mounted)
        setState(() =>
            _notificationError = 'No pudimos actualizar las notificaciones.');
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
    if (mounted) _reload();
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
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: UnreadNotificationsNotifier.instance,
      builder: (context, unread, _) => MessagesInbox(
          threads: _threads,
          notifications: _notifications,
          unreadNotifications: unread,
          loading: _loading,
          error: _error,
          notificationError: _notificationError,
          onRefresh: _load,
          onNotifications: _openNotifications,
          onNotification: _openNotification,
          onThread: _openThread));
}

class MessagesInbox extends StatelessWidget {
  const MessagesInbox(
      {required this.threads,
      required this.notifications,
      required this.unreadNotifications,
      required this.onRefresh,
      required this.onNotifications,
      required this.onNotification,
      required this.onThread,
      this.loading = false,
      this.error,
      this.notificationError,
      super.key});
  final List<ChatThread> threads;
  final List<AppNotification> notifications;
  final int unreadNotifications;
  final bool loading;
  final String? error, notificationError;
  final Future<void> Function() onRefresh;
  final VoidCallback onNotifications;
  final ValueChanged<AppNotification> onNotification;
  final ValueChanged<ChatThread> onThread;
  static const _ink = AppTheme.colorText, _muted = AppTheme.colorMuted;

  @override
  Widget build(BuildContext context) {
    final confirmed = threads
        .where((thread) => thread.chatEnabled && thread.jobId.isNotEmpty)
        .toList();
    final active = confirmed.where((thread) => thread.isActive).toList();
    final archived = confirmed.where((thread) => !thread.isActive).toList();
    return Theme(
        data: Theme.of(context).copyWith(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
                seedColor: AppTheme.colorPrimary,
                brightness: Brightness.light)),
        child: Scaffold(
            backgroundColor: AppTheme.colorBackground,
            body: SafeArea(
                child: RefreshIndicator(
                    onRefresh: onRefresh,
                    child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 22, 20, 20),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text('Mensajes',
                                                  style: TextStyle(
                                                      fontSize: 28,
                                                      color: _ink,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              SizedBox(height: 5),
                                              Text(
                                                  'Tus trabajos, ofertas y novedades\nen un solo lugar.',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: _muted,
                                                      height: 1.5))
                                            ])),
                                        const SizedBox(width: 12),
                                        NotificationBell(
                                            unread: unreadNotifications,
                                            onPressed: onNotifications),
                                      ]))),
                          SliverToBoxAdapter(
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _notificationSummary())),
                          if (error != null || notificationError != null)
                            SliverToBoxAdapter(
                                child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 12, 20, 0),
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
                                    padding: EdgeInsets.only(top: 24),
                                    child: SkeletonList(
                                        count: 5,
                                        lines: 3,
                                        circleLeading: false,
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero))),
                          if (active.isNotEmpty) ...[
                            const SliverToBoxAdapter(
                                child: _SectionLabel('Trabajos confirmados')),
                            SliverList.builder(
                                itemCount: active.length,
                                itemBuilder: (context, index) =>
                                    _threadTile(active[index])),
                          ],
                          if (notifications.isNotEmpty) ...[
                            const SliverToBoxAdapter(
                                child: _SectionLabel('Actividad reciente')),
                            SliverList.builder(
                                itemCount: notifications.length,
                                itemBuilder: (context, index) =>
                                    _notificationTile(notifications[index])),
                            SliverToBoxAdapter(
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: TextButton(
                                        onPressed: onNotifications,
                                        child: const Text(
                                            'Ver todas las notificaciones')))),
                          ],
                          if (!loading && notifications.isEmpty && active.isEmpty)
                            SliverToBoxAdapter(
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28, vertical: 30),
                                    child: Column(children: [
                                      const Icon(
                                          Icons.notifications_none_rounded,
                                          color: AppTheme.colorPrimaryLight,
                                          size: 40),
                                      const SizedBox(height: 12),
                                      Text(
                                          notificationError == null
                                              ? 'Estás al día'
                                              : 'Tu actividad sigue aquí',
                                          style: const TextStyle(
                                              color: _ink,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      const Text(
                                          'Las novedades de tus trabajos aparecerán aquí.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: _muted,
                                              fontSize: 12,
                                              height: 1.5))
                                    ]))),
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

  Widget _notificationSummary() => ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
              color: AppTheme.colorPrimaryTint,
              child: InkWell(
                  onTap: onNotifications,
                  child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.colorPrimary
                                  .withValues(alpha: 0.14)),
                          borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle),
                            child: const Icon(
                                Icons.notifications_active_rounded,
                                color: AppTheme.colorPrimary,
                                size: 27)),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Notificaciones',
                                  style: TextStyle(
                                      color: _ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 5),
                              Text(
                                  unreadNotifications == 0
                                      ? 'No hay notificaciones nuevas'
                                      : '$unreadNotifications ${unreadNotifications == 1 ? 'notificación nueva' : 'notificaciones nuevas'}',
                                  style: const TextStyle(
                                      color: _muted, fontSize: 12),
                                  maxLines: 2)
                            ])),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.colorPrimary, size: 24),
                      ])))));

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
                Text(notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class NotificationBell extends StatelessWidget {
  const NotificationBell(
      {required this.unread, required this.onPressed, super.key});
  final int unread;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.colorGlassBorder),
          boxShadow: AppTheme.shadowSm),
      child: IconButton(
          tooltip: unread == 0
              ? 'Notificaciones'
              : '$unread notificaciones sin leer',
          onPressed: onPressed,
          icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: AppTheme.colorError,
              child: const Icon(Icons.notifications_none_rounded,
                  color: AppTheme.colorPrimary, size: 24))));
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
