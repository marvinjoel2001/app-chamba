import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/push/notification_router.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_notifications_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../data/notifications_service.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/notification_counts.dart';
import '../notification_card_presentation.dart';
import '../notification_style.dart';

typedef NotificationPage = ({List<AppNotification> items, bool hasMore});

enum NotificationReadFilter { all, unread, read }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen(
      {super.key,
      this.previewItems,
      this.loadPage,
      this.loadCounts,
      this.markRead,
      this.onOpenNotification,
      this.isActive = true,
      this.header,
      this.onRefreshHeader});

  /// In-memory preview and injected boundaries keep QA isolated from real accounts.
  final List<AppNotification>? previewItems;
  final Future<NotificationPage> Function(int page)? loadPage;
  final Future<NotificationTypeCounts> Function()? loadCounts;
  final Future<void> Function(List<String> ids)? markRead;
  final bool Function(AppNotification notification)? onOpenNotification;
  final bool isActive;
  final Widget? header;
  final Future<void> Function()? onRefreshHeader;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  List<AppNotification> _notifications = [];
  bool _isLoading = true,
      _isLoadingMore = false,
      _hasMore = true,
      _markingRead = false;
  int _currentPage = 1, _generation = 0;
  String? _error, _moreError;
  NotificationCategory _category = NotificationCategory.all;
  NotificationReadFilter _readFilter = NotificationReadFilter.all;
  NotificationTypeCounts? _serverCounts;
  int _countGeneration = 0;
  bool _countsFailed = false;
  final _scrollController = ScrollController();
  final _pendingReadIds = <String>{};
  final _realtime = RealtimeService.instance;
  Timer? _refreshDebounce;

  List<AppNotification> get _visible => _notifications
      .where((n) =>
          (_category == NotificationCategory.all ||
              NotificationCardPresentation.categoryOf(n.type) == _category) &&
          (_readFilter == NotificationReadFilter.all ||
              (_readFilter == NotificationReadFilter.read
                  ? n.isRead
                  : !n.isRead)))
      .toList();

  ({int unread, int read}) get _counts {
    var unread = 0, read = 0;
    if (_serverCounts != null) {
      for (final entry in _serverCounts!.entries) {
        if (NotificationCardPresentation.isVisibleInCenter(entry.key) &&
            (_category == NotificationCategory.all ||
                NotificationCardPresentation.categoryOf(entry.key) ==
                    _category)) {
          unread += entry.value.unread;
          read += entry.value.read;
        }
      }
    } else {
      for (final n in _notifications) {
        if (_category == NotificationCategory.all ||
            NotificationCardPresentation.categoryOf(n.type) == _category) {
          if (n.isRead) {
            read++;
          } else {
            unread++;
          }
        }
      }
    }
    return (unread: unread, read: read);
  }

  Future<void> _refreshCounts() async {
    if (widget.loadCounts == null &&
        (widget.previewItems != null || widget.loadPage != null)) {
      return;
    }
    final generation = ++_countGeneration;
    final account = SessionStore.currentUser?.id;
    try {
      final counts =
          await (widget.loadCounts?.call() ?? NotificationsService.getCounts());
      if (mounted &&
          generation == _countGeneration &&
          SessionStore.currentUser?.id == account) {
        setState(() => _serverCounts = counts);
      }
    } catch (_) {
      // A failed count request must not discard the loaded list or mark it read.
      if (mounted && generation == _countGeneration) {
        setState(() => _countsFailed = true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtime.on('notification.new', _onNotificationEvent);
    _realtime.on('notifications.changed', _onNotificationEvent);
    _realtime.reconnectCount.addListener(_refreshWhenActive);
    _scrollController.addListener(_onScroll);
    _loadNotifications();
  }

  void _onNotificationEvent(dynamic _) => _refreshWhenActive();

  void _refreshWhenActive() {
    if (!widget.isActive) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted && widget.isActive) _loadNotifications();
    });
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.isActive && widget.isActive) ||
        oldWidget.previewItems != widget.previewItems) {
      _loadNotifications();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshWhenActive();
  }

  @override
  void dispose() {
    _generation++;
    _countGeneration++;
    _refreshDebounce?.cancel();
    _realtime.off('notification.new', _onNotificationEvent);
    _realtime.off('notifications.changed', _onNotificationEvent);
    _realtime.reconnectCount.removeListener(_refreshWhenActive);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 180 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore &&
        _moreError == null) {
      _loadMoreNotifications();
    }
  }

  Future<NotificationPage> _page(int page) =>
      widget.loadPage?.call(page) ??
      NotificationsService.getNotifications(page: page, limit: 20);
  Future<void> _loadNotifications() async {
    final generation = ++_generation;
    _countGeneration++;
    final account = SessionStore.currentUser?.id;
    setState(() {
      _serverCounts = null;
      _countsFailed = false;
      _isLoading = true;
      _isLoadingMore = false;
      _error = null;
      _moreError = null;
    });
    try {
      final preview = widget.previewItems;
      final result = preview != null
          ? (items: List<AppNotification>.from(preview), hasMore: false)
          : await _page(1);
      if (!mounted ||
          generation != _generation ||
          SessionStore.currentUser?.id != account) {
        return;
      }
      setState(() {
        _notifications = result.items
            .where(
                (n) => NotificationCardPresentation.isVisibleInCenter(n.type))
            .toList();
        _hasMore = result.hasMore;
        _currentPage = 1;
        _isLoading = false;
      });
      unawaited(_refreshCounts());
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = 'No pudimos cargar tus notificaciones. Revisa tu conexión.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final generation = _generation;
    final account = SessionStore.currentUser?.id;
    final page = _currentPage + 1;
    setState(() {
      _isLoadingMore = true;
      _moreError = null;
    });
    try {
      final result = await _page(page);
      if (!mounted ||
          generation != _generation ||
          SessionStore.currentUser?.id != account) {
        return;
      }
      final existing = _notifications.map((n) => n.id).toSet();
      setState(() {
        _notifications.addAll(result.items.where((n) =>
            NotificationCardPresentation.isVisibleInCenter(n.type) &&
            existing.add(n.id)));
        _hasMore = result.hasMore;
        _currentPage = page;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _isLoadingMore = false;
        _moreError = 'No pudimos cargar más avisos.';
      });
    }
  }

  Future<void> _markRead(List<AppNotification> items) async {
    final ids = items.where((n) => !n.isRead).map((n) => n.id).toList();
    _pendingReadIds.addAll(ids);
    if (_pendingReadIds.isEmpty || _markingRead) return;
    final account = SessionStore.currentUser?.id;
    setState(() => _markingRead = true);
    try {
      while (_pendingReadIds.isNotEmpty) {
        final batch = _pendingReadIds.take(100).toList();
        _pendingReadIds.removeAll(batch);
        if (widget.markRead != null) {
          await widget.markRead!(batch);
        } else if (widget.previewItems == null) {
          await NotificationsService.markAsRead(ids: batch);
        }
        if (!mounted || SessionStore.currentUser?.id != account) {
          _pendingReadIds.clear();
          return;
        }
        setState(() {
          _countGeneration++;
          if (_serverCounts != null) {
            final updatedCounts = NotificationTypeCounts.from(_serverCounts!);
            for (final n in _notifications
                .where((n) => batch.contains(n.id) && !n.isRead)) {
              final count = updatedCounts[n.type];
              if (count != null && count.unread > 0) {
                updatedCounts[n.type] =
                    (unread: count.unread - 1, read: count.read + 1);
              }
            }
            _serverCounts = updatedCounts;
          }
          _notifications = _notifications
              .map((n) => batch.contains(n.id)
                  ? AppNotification(
                      id: n.id,
                      title: n.title,
                      body: n.body,
                      type: n.type,
                      isRead: true,
                      createdAt: n.createdAt,
                      data: n.data)
                  : n)
              .toList();
        });
      }
      if (widget.previewItems == null && widget.markRead == null) {
        unawaited(UnreadNotificationsNotifier.instance.refresh());
      }
      unawaited(_refreshCounts());
    } catch (_) {
      _pendingReadIds.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos marcar los avisos como leídos. Inténtalo de nuevo.')));
      }
    } finally {
      if (mounted) setState(() => _markingRead = false);
    }
  }

  void _openNotification(AppNotification notification) {
    unawaited(_markRead([notification]));
    final hasAction = NotificationCardPresentation.actionLabel(notification,
            role: SessionStore.currentUser?.type ?? 'client') !=
        'Ver detalle';
    final opened = widget.onOpenNotification?.call(notification) ??
        (hasAction &&
            NotificationRouter.openFromData(
                {...?notification.data, 'type': notification.type},
                fromNotificationCenter: true));
    if (!opened) {
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification.title,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                            dateTimeLabel(notification.createdAt,
                                relative: false),
                            style: const TextStyle(color: AppTheme.colorMuted)),
                        const SizedBox(height: 16),
                        Text(notification.body,
                            style: const TextStyle(height: 1.5)),
                        const SizedBox(height: 20),
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cerrar'))),
                      ]))));
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SkeletonList(count: 4, lines: 3, circleLeading: false);
    }
    if (_error != null && _notifications.isEmpty) {
      return Center(
          child: ChambaEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Sin conexión',
              message: _error,
              actionLabel: 'Reintentar',
              onAction: _loadNotifications));
    }
    final visible = _visible;
    final matchingCount = _readFilter == NotificationReadFilter.unread
        ? _counts.unread
        : _readFilter == NotificationReadFilter.read
            ? _counts.read
            : _counts.unread + _counts.read;
    return RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadNotifications(),
            if (widget.onRefreshHeader != null) widget.onRefreshHeader!(),
          ]);
        },
        child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (widget.header != null &&
                  _readFilter == NotificationReadFilter.all &&
                  (_category == NotificationCategory.all ||
                      _category == NotificationCategory.messages))
                widget.header!,
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: AppTheme.colorError))),
              if (visible.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: ChambaEmptyState(
                        icon: _category.icon,
                        title: _hasMore &&
                                (_serverCounts == null || matchingCount > 0)
                            ? 'Hay más avisos para revisar'
                            : _readFilter == NotificationReadFilter.unread
                                ? 'No tienes avisos nuevos'
                                : _readFilter == NotificationReadFilter.read
                                    ? 'No hay avisos leídos aquí'
                                    : _category == NotificationCategory.all
                                        ? 'Estás al día'
                                        : 'Sin avisos de ${_category.label.toLowerCase()}',
                        message: _hasMore
                            ? 'Puedes cargar más avisos o elegir otra categoría.'
                            : 'Los nuevos avisos aparecerán aquí.')),
              for (final notification in visible)
                _NotificationCard(
                    notification: notification,
                    onTap: () => _openNotification(notification)),
              if (_isLoadingMore)
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator())),
              if (_hasMore && !_isLoadingMore)
                Center(
                    child: TextButton.icon(
                        onPressed: _loadMoreNotifications,
                        icon: Icon(_moreError == null
                            ? Icons.expand_more
                            : Icons.refresh),
                        label: Text(_moreError ?? 'Cargar más avisos'))),
            ]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFAF9FF),
        appBar: AppBar(
            centerTitle: false,
            title: const Text('Notificaciones',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            backgroundColor: const Color(0xFFFAF9FF),
            actions: [
              PopupMenuButton<String>(
                  tooltip: 'Opciones de notificaciones',
                  icon: const Icon(Icons.tune_rounded),
                  onSelected: (value) {
                    if (value == 'refresh') {
                      _loadNotifications();
                    } else {
                      _markRead(_visible);
                    }
                  },
                  itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'refresh', child: Text('Actualizar')),
                        PopupMenuItem(
                            value: 'read',
                            enabled:
                                !_markingRead && _visible.any((n) => !n.isRead),
                            child: const Text('Marcar visibles como leídas')),
                      ]),
            ]),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                  _countsFailed && _serverCounts == null && _hasMore
                      ? 'Conteo de los avisos cargados.'
                      : 'Resumen visual de tus actividades.',
                  style: const TextStyle(
                      color: AppTheme.colorMuted, fontSize: 13))),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                for (final entry in [
                  (
                    filter: NotificationReadFilter.all,
                    label: 'Todas',
                    count: _counts.unread + _counts.read
                  ),
                  (
                    filter: NotificationReadFilter.unread,
                    label: 'Nuevas',
                    count: _counts.unread
                  ),
                  (
                    filter: NotificationReadFilter.read,
                    label: 'Leídas',
                    count: _counts.read
                  ),
                ])
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text('${entry.label} ${entry.count}'),
                            selected: _readFilter == entry.filter,
                            showCheckmark: false,
                            selectedColor: AppTheme.colorPrimaryTint,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                                fontFamily: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _readFilter == entry.filter
                                    ? AppTheme.colorPrimaryDark
                                    : AppTheme.colorMuted),
                            onSelected: (_) =>
                                setState(() => _readFilter = entry.filter),
                          ))),
              ])),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(children: [
                for (final category in NotificationCategory.values)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          label: Text(category.label),
                          selected: _category == category,
                          showCheckmark: false,
                          selectedColor: AppTheme.colorPrimary,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                              fontFamily: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _category == category
                                  ? Colors.white
                                  : AppTheme.colorMuted),
                          side: const BorderSide(
                              color: AppTheme.colorGlassBorder),
                          onSelected: (_) =>
                              setState(() => _category = category))),
              ])),
          Expanded(child: _buildBody()),
        ]),
      );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final presentation = NotificationCardPresentation.of(notification.type);
    final style = NotificationStyle.of(notification.type);
    final label = NotificationCardPresentation.actionLabel(notification,
        role: SessionStore.currentUser?.type ?? 'client');
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
            color: presentation.background,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                        color: presentation.color,
                                        shape: BoxShape.circle),
                                    child: Icon(style.icon,
                                        size: 19, color: Colors.white)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(notification.title,
                                          style: const TextStyle(
                                              color: AppTheme.colorText,
                                              fontSize: 14,
                                              height: 1.3,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 3),
                                      Text(
                                          dateTimeLabel(notification.createdAt,
                                              relative: false),
                                          style: const TextStyle(
                                              color: AppTheme.colorMuted,
                                              fontSize: 11,
                                              height: 1.3)),
                                    ])),
                                Padding(
                                    padding: EdgeInsets.only(left: 8, top: 3),
                                    child: Semantics(
                                        label: notification.isRead
                                            ? 'Notificación leída'
                                            : 'Sin leer',
                                        child: Text(
                                            notification.isRead
                                                ? 'Leída'
                                                : 'Nueva',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: notification.isRead
                                                    ? AppTheme.colorMuted
                                                    : AppTheme.colorPrimary)))),
                              ]),
                          const SizedBox(height: 10),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      if (notification.body.isNotEmpty)
                                        Text(notification.body,
                                            style: const TextStyle(
                                                color: AppTheme.colorMuted,
                                                fontSize: 12,
                                                height: 1.45)),
                                      const SizedBox(height: 10),
                                      OutlinedButton(
                                          onPressed: onTap,
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  presentation.color,
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.8),
                                              side: BorderSide(
                                                  color: presentation.color),
                                              minimumSize: const Size(0, 40),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8),
                                              textStyle: TextStyle(
                                                  fontFamily: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge
                                                      ?.fontFamily,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700)),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(child: Text(label)),
                                                const SizedBox(width: 6),
                                                const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 15)
                                              ])),
                                    ])),
                                if (presentation.asset != null &&
                                    !largeText) ...[
                                  const SizedBox(width: 12),
                                  Image.asset(
                                      'assets/images/notifications/${presentation.asset}.png',
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.contain,
                                      cacheWidth: 252,
                                      excludeFromSemantics: true)
                                ],
                              ]),
                        ])))));
  }
}
