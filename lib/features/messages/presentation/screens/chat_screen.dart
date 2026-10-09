import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_credentials.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../data/models/chat_message_model.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../../domain/job_chat_policy.dart';
import '../../domain/usecases/messages_usecases.dart';
import '../state/messages_dependencies.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen(
      {required this.threadId,
      this.jobId = '',
      this.jobTitle = 'Trabajo',
      this.jobStatus = ChatThreadStatus.pending,
      this.agreedPrice = 0,
      this.counterpartName = '',
      this.counterpartId,
      this.counterpartAvatarUrl,
      this.counterpartPhone,
      this.category,
      this.workerId,
      this.isArchived = false,
      this.getThreadMessagesUseCase,
      this.sendMessageUseCase,
      super.key});
  final String threadId, jobId, jobTitle, counterpartName;
  final ChatThreadStatus jobStatus;
  final double agreedPrice;
  final String? counterpartId,
      counterpartAvatarUrl,
      counterpartPhone,
      category,
      workerId;
  final bool isArchived;
  final GetThreadMessagesUseCase? getThreadMessagesUseCase;
  final SendMessageUseCase? sendMessageUseCase;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with RouteAware, WidgetsBindingObserver {
  static const _ink = Color(0xFF19152C), _muted = Color(0xFF77718E);
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _realtime = RealtimeService.instance;
  ChatThread? _thread;
  List<ChatMessage> _messages = [];
  File? _photo;
  String? _error;
  bool _loading = true,
      _sending = false,
      _hasMore = false,
      _loadingOlder = false;
  bool _closed = false, _refreshing = false, _refreshAgain = false;
  Timer? _readDebounce, _statusPoll;
  GetThreadMessagesUseCase get _getMessages =>
      widget.getThreadMessagesUseCase ?? MessagesDependencies.getThreadMessages;
  SendMessageUseCase get _sendMessage =>
      widget.sendMessageUseCase ?? MessagesDependencies.sendMessage;
  bool get _canSend =>
      _thread?.canSend == true && !_closed && !widget.isArchived;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtime.connect(userId: SessionStore.currentUser?.id);
    _realtime.on('message.new', _onMessage);
    _realtime.on('job.client_confirmed', _onWorkStarted);
    for (final event in [
      'request.status.updated',
      'job.completed',
      'job.cancelled'
    ]) {
      _realtime.on(event, _onJobStatus);
    }
    _realtime.reconnectCount.addListener(_reload);
    _scroll.addListener(_onScroll);
    _statusPoll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)
        _reload();
    });
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) ChambaApp.routeObserver.subscribe(this, route);
    if (route?.isCurrent == true)
      SessionCredentials.visibleThreadId = widget.threadId;
  }

  @override
  void didPopNext() {
    SessionCredentials.visibleThreadId = widget.threadId;
    _reload();
  }

  @override
  void didPush() {
    SessionCredentials.visibleThreadId = widget.threadId;
  }

  @override
  void didPushNext() {
    if (SessionCredentials.visibleThreadId == widget.threadId)
      SessionCredentials.visibleThreadId = null;
  }

  @override
  void didPop() => didPushNext();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    _readDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ChambaApp.routeObserver.unsubscribe(this);
    didPushNext();
    _realtime.leaveThread(widget.threadId);
    _realtime.off('message.new', _onMessage);
    _realtime.off('job.client_confirmed', _onWorkStarted);
    for (final event in [
      'request.status.updated',
      'job.completed',
      'job.cancelled'
    ]) {
      _realtime.off(event, _onJobStatus);
    }
    _realtime.reconnectCount.removeListener(_reload);
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    try {
      return Map<String, dynamic>.from(jsonDecode(value.toString()) as Map);
    } catch (_) {
      return {};
    }
  }

  void _onWorkStarted(dynamic value) {
    final data = _payload(value);
    if (mounted &&
        data['requestId']?.toString() == (_thread?.jobId ?? widget.jobId)) {
      _reload();
    }
  }

  void _onJobStatus(dynamic value) {
    final data = _payload(value);
    if (!mounted ||
        data['requestId']?.toString() != (_thread?.jobId ?? widget.jobId))
      return;
    if (data['status'] == 'completed' ||
        data['status'] == 'cancelled' ||
        !data.containsKey('status')) {
      setState(() {
        _closed = true;
        _photo = null;
      });
      _focus.unfocus();
    }
    _reload();
  }

  void _onMessage(dynamic value) {
    final data = _payload(value);
    if (data['threadId']?.toString() != widget.threadId ||
        !mounted ||
        _thread == null ||
        data['message'] is! Map) return;
    _append(ChatMessageModel.fromJson(
        Map<String, dynamic>.from(data['message'] as Map)));
  }

  void _append(ChatMessage message) {
    if (_messages.any((item) => item.id == message.id)) return;
    final atBottom = !_scroll.hasClients || _scroll.position.extentAfter < 100;
    setState(() => _messages = [..._messages, message]);
    if (atBottom) _scrollToBottom();
  }

  void _reload() => unawaited(_load());
  Future<void> _load() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    final first = _thread == null;
    final result = await _getMessages(threadId: widget.threadId);
    if (!mounted) return;
    result.fold(onSuccess: (conversation) {
      setState(() {
        _thread = conversation.thread;
        _closed = !_thread!.canSend;
        if (_closed) _photo = null;
        final byId = {for (final message in _messages) message.id: message};
        for (final message in conversation.messages) {
          byId[message.id] = message;
        }
        _messages = byId.values.toList()
          ..sort((a, b) => (a.createdAt ?? DateTime(0))
              .compareTo(b.createdAt ?? DateTime(0)));
        if (first) _hasMore = conversation.hasMore;
        _loading = false;
        _error = null;
      });
      _realtime.joinThread(widget.threadId);
      if (first) _scrollToBottom();
      _scheduleRead();
    }, onFailure: (failure) {
      setState(() {
        _loading = false;
        _error = failure is NetworkFailure
            ? 'Sin conexión. Reintenta para actualizar el chat.'
            : failure.message;
        _closed = true;
        _photo = null;
      });
    });
    _refreshing = false;
    if (_refreshAgain) {
      _refreshAgain = false;
      _reload();
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _messages.isEmpty) return;
    final before = _messages.first.createdAt?.toUtc().toIso8601String();
    if (before == null) return;
    final extent = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    setState(() => _loadingOlder = true);
    final result =
        await _getMessages(threadId: widget.threadId, before: before);
    if (!mounted) return;
    result.fold(
        onSuccess: (page) {
          setState(() {
            _thread = page.thread;
            _closed = !_thread!.canSend;
            final ids = _messages.map((message) => message.id).toSet();
            _messages = [
              ...page.messages.where((message) => !ids.contains(message.id)),
              ..._messages
            ];
            _hasMore = page.hasMore;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scroll.hasClients)
              _scroll
                  .jumpTo(offset + _scroll.position.maxScrollExtent - extent);
          });
        },
        onFailure: (failure) => _showError(failure.message));
    setState(() => _loadingOlder = false);
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 100)
      _scheduleRead();
  }

  void _scheduleRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 400), () async {
      final user = SessionStore.currentUser;
      if (user == null ||
          SessionCredentials.accessToken == null ||
          !mounted ||
          _thread == null ||
          SessionCredentials.visibleThreadId != widget.threadId ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          (_scroll.hasClients && _scroll.position.extentAfter >= 100)) return;
      try {
        await MobileBackendService.instance
            .markThreadRead(threadId: widget.threadId, userId: user.id);
        await UnreadMessagesNotifier.instance.refresh();
      } catch (_) {/* Retry on the next visible read. */}
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients)
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  Future<void> _showContactAlert() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              icon: const Icon(Icons.shield_outlined,
                  color: AppTheme.colorPrimary, size: 36),
              title: const Text('Mantengamos tu trabajo protegido',
                  style: TextStyle(color: _ink, fontSize: 20)),
              content: const Text(JobChatPolicy.contactAlert,
                  style: TextStyle(color: _muted, height: 1.5)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'))
              ]));
  void _showError(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send() async {
    if (_sending || !_canSend || SessionStore.currentUser == null) return;
    final draft = _controller.text.trim();
    if (draft.isEmpty && _photo == null) return;
    if (JobChatPolicy.containsExternalContact(draft)) {
      await _showContactAlert();
      return;
    }
    if (draft.length > 2000) {
      _showError('Escribe un mensaje de hasta 2000 caracteres.');
      return;
    }
    setState(() => _sending = true);
    final photo = _photo;
    try {
      ChatMessage? sent;
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (bytes.length > 6 * 1024 * 1024) {
          _showError('La foto debe pesar menos de 6 MB.');
          return;
        }
        final ext = photo.path.toLowerCase();
        final mime = ext.endsWith('.png')
            ? 'png'
            : ext.endsWith('.webp')
                ? 'webp'
                : 'jpeg';
        final response = await MobileBackendService.instance.sendChatPhoto(
            threadId: widget.threadId,
            imageBase64: 'data:image/$mime;base64,${base64Encode(bytes)}',
            caption: draft);
        sent = ChatMessageModel.fromJson(
            Map<String, dynamic>.from(response['message'] as Map));
      } else {
        final result = await _sendMessage(
            threadId: widget.threadId,
            senderUserId: SessionStore.currentUser!.id,
            content: draft);
        result.fold(
            onSuccess: (message) => sent = message,
            onFailure: (failure) => throw failure);
      }
      if (!mounted) return;
      if (sent != null) {
        _controller.clear();
        setState(() => _photo = null);
        _append(sent!);
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is Failure
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');
      if (message.contains('Por tu seguridad')) {
        await _showContactAlert();
      } else {
        _showError(message);
      }
      _reload();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (!_canSend || _sending) return;
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.photo_camera_outlined,
                      color: AppTheme.colorPrimary),
                  title: const Text('Tomar foto del trabajo',
                      style: TextStyle(color: _ink)),
                  onTap: () => Navigator.pop(context, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: AppTheme.colorPrimary),
                  title:
                      const Text('Elegir foto', style: TextStyle(color: _ink)),
                  onTap: () => Navigator.pop(context, ImageSource.gallery))
            ])));
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
          source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
      if (mounted && picked != null && _canSend)
        setState(() => _photo = File(picked.path));
    } catch (_) {
      _showError(
          'No pudimos abrir la foto. Revisa los permisos de cámara o galería.');
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: Theme.of(context).copyWith(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.colorPrimary, brightness: Brightness.light)),
      child: Scaffold(
          backgroundColor: const Color(0xFFF6F5FC),
          appBar: AppBar(
              backgroundColor: const Color(0xFFF6F5FC),
              foregroundColor: _ink,
              elevation: 0,
              titleSpacing: 0,
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chat del trabajo',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(_thread?.counterpartName ?? widget.counterpartName,
                        style: const TextStyle(fontSize: 12, color: _muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)
                  ]),
              actions: [
                IconButton(
                    tooltip: 'Actualizar chat',
                    onPressed: _loading ? null : _reload,
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppTheme.colorPrimary))
              ]),
          body: SafeArea(
              top: false,
              child: Column(children: [
                if (_thread != null) _jobHeader(_thread!),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: _muted, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: const TextStyle(color: _muted))),
                        IconButton(
                            tooltip: 'Reintentar',
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh,
                                color: AppTheme.colorPrimary))
                      ])),
                Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _thread == null
                            ? const Center(
                                child: Icon(Icons.lock_outline_rounded,
                                    size: 48,
                                    color: AppTheme.colorPrimaryLight))
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.builder(
                                    controller: _scroll,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 16),
                                    itemCount: _messages.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == 0)
                                        return Column(children: [
                                          if (_hasMore)
                                            TextButton.icon(
                                                onPressed: _loadingOlder
                                                    ? null
                                                    : _loadOlder,
                                                icon: const Icon(
                                                    Icons.history_rounded,
                                                    size: 16),
                                                label: Text(_loadingOlder
                                                    ? 'Cargando historial...'
                                                    : 'Mensajes anteriores')),
                                          if (_messages.isEmpty)
                                            const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 36),
                                                child: Text(
                                                    'Tu trabajo, una conversación.\nTodo listo para coordinar.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        color: _muted,
                                                        height: 1.6)))
                                        ]);
                                      final message = _messages[index - 1];
                                      final previous = index > 1
                                          ? _messages[index - 2].createdAt
                                          : null;
                                      final date = message.createdAt;
                                      final newDay = previous == null ||
                                          date == null ||
                                          DateUtils.dateOnly(previous) !=
                                              DateUtils.dateOnly(date);
                                      return Column(children: [
                                        if (newDay) _dateLabel(date),
                                        _bubble(message)
                                      ]);
                                    }))),
                if (_thread != null && !_canSend)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Row(children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: AppTheme.colorPrimary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                _error != null
                                    ? 'Actualiza el chat para poder enviar mensajes.'
                                    : 'Este trabajo terminó. Conservamos tu conversación.',
                                style: const TextStyle(
                                    color: _muted, fontSize: 12, height: 1.5)))
                      ])),
                if (_canSend) ...[
                  if (_photo == null) _quickReplies(),
                  _composer()
                ],
              ]))));

  Widget _jobHeader(ChatThread thread) => ClipRect(
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  border: Border(
                      bottom: BorderSide(
                          color:
                              AppTheme.colorPrimary.withValues(alpha: 0.12)))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: const Color(0xFFEDE6FF),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.work_outline_rounded,
                              color: AppTheme.colorPrimary)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(thread.jobTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(
                                '${thread.category ?? 'Trabajo confirmado'} · Bs ${thread.agreedPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: _muted, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)
                          ])),
                      const SizedBox(width: 8),
                      Icon(
                          _canSend
                              ? Icons.verified_outlined
                              : Icons.lock_outline,
                          color: _canSend
                              ? const Color(0xFF35A883)
                              : AppTheme.colorPrimary,
                          size: 20)
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.shield_outlined,
                          size: 14, color: AppTheme.colorPrimary),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              _canSend
                                  ? 'Coordinación protegida en Chamba'
                                  : 'Historial del trabajo · solo lectura',
                              style:
                                  const TextStyle(color: _muted, fontSize: 11)))
                    ]),
                  ]))));

  Widget _quickReplies() => SizedBox(
      height: 54,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          itemCount: JobChatPolicy.quickReplies.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => ActionChip(
              avatar: Icon(
                  [
                    Icons.door_front_door_outlined,
                    Icons.schedule_rounded,
                    Icons.near_me_outlined,
                    Icons.help_outline_rounded
                  ][index],
                  size: 16,
                  color: AppTheme.colorPrimary),
              label: Text(JobChatPolicy.quickReplies[index],
                  style: const TextStyle(
                      color: AppTheme.colorPrimaryDark, fontSize: 12)),
              backgroundColor: const Color(0xFFEEE9FB),
              side: BorderSide.none,
              onPressed: _sending
                  ? null
                  : () {
                      _controller.text = JobChatPolicy.quickReplies[index];
                      _controller.selection = TextSelection.collapsed(
                          offset: _controller.text.length);
                      _focus.requestFocus();
                    })));
  Widget _composer() => Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          border: const Border(top: BorderSide(color: Color(0xFFEDE9F7)))),
      child: Column(children: [
        if (_photo != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_photo!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover)),
                Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filled(
                        tooltip: 'Quitar foto',
                        onPressed: _sending
                            ? null
                            : () => setState(() => _photo = null),
                        icon: const Icon(Icons.close)))
              ])),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          IconButton(
              tooltip: 'Foto del trabajo',
              onPressed: _sending ? null : _pickPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  color: AppTheme.colorPrimary)),
          Expanded(
              child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: _ink, fontSize: 14),
                  decoration: InputDecoration(
                      hintText: _photo == null
                          ? 'Coordina este trabajo...'
                          : 'Descripción de la foto...',
                      hintStyle: const TextStyle(color: _muted),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF6F4FC),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                              color: AppTheme.colorPrimaryLight))))),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => IconButton.filled(
                  tooltip: _photo == null
                      ? 'Enviar mensaje'
                      : 'Revisar y enviar foto',
                  style: IconButton.styleFrom(
                      backgroundColor: AppTheme.colorPrimary,
                      disabledBackgroundColor: const Color(0xFFEAE5F4)),
                  onPressed:
                      _sending || (value.text.trim().isEmpty && _photo == null)
                          ? null
                          : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded)))
        ]),
        if (_sending && _photo != null)
          const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Revisando y enviando foto...',
                  style: TextStyle(color: _muted, fontSize: 11))),
      ]));
  Widget _dateLabel(DateTime? date) {
    if (date == null) return const SizedBox.shrink();
    final diff = DateUtils.dateOnly(DateTime.now())
        .difference(DateUtils.dateOnly(date))
        .inDays;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
            diff == 0
                ? 'Hoy'
                : diff == 1
                    ? 'Ayer'
                    : '${date.day}/${date.month}/${date.year}',
            style: const TextStyle(
                color: _muted, fontSize: 11, fontWeight: FontWeight.w500)));
  }

  Widget _bubble(ChatMessage message) {
    if (message.isSystem)
      return Padding(
          padding: const EdgeInsets.all(12),
          child: Text(message.displayContent,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12)));
    final mine = message.senderUserId == SessionStore.currentUser?.id;
    final content = message.content ?? '';
    final lines = content.split('\n');
    final isPhoto = (content.startsWith('[Foto]\n') ||
            content.startsWith('📷 Imagen enviada\n')) &&
        lines.length >= 2;
    final uri = isPhoto ? Uri.tryParse(lines[1]) : null;
    final photoUrl = uri?.scheme == 'https' && uri?.host == 'res.cloudinary.com'
        ? uri.toString()
        : null;
    final caption = isPhoto ? lines.skip(2).join('\n') : content;
    final date = message.createdAt;
    return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: mine ? AppTheme.colorPrimary : Colors.white,
                border:
                    mine ? null : Border.all(color: const Color(0xFFEDE9F7)),
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 18))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (photoUrl != null)
                    GestureDetector(
                        onTap: () => _viewPhoto(photoUrl),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ChambaNetworkImage(
                                url: photoUrl,
                                width: 230,
                                height: 200,
                                fit: BoxFit.cover))),
                  if (photoUrl != null && caption.isNotEmpty)
                    const SizedBox(height: 8),
                  if (caption.isNotEmpty || (isPhoto && photoUrl == null))
                    Text(
                        isPhoto && photoUrl == null
                            ? 'Foto del trabajo'
                            : caption,
                        style: TextStyle(
                            color: mine ? Colors.white : _ink,
                            fontSize: 14,
                            height: 1.5)),
                  const SizedBox(height: 6),
                  Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                          date == null
                              ? ''
                              : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              color: mine ? Colors.white70 : _muted,
                              fontSize: 10))),
                ])));
  }

  void _viewPhoto(String url) => showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
              child: Stack(children: [
            Center(
                child: InteractiveViewer(
                    child: ChambaNetworkImage(url: url, fit: BoxFit.contain))),
            Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                    tooltip: 'Cerrar foto',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white)))
          ]))));
}
