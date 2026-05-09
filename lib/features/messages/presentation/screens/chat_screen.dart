import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../request/presentation/screens/request_form_screen.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../../domain/usecases/messages_usecases.dart';
import '../state/messages_dependencies.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.threadId,
    this.jobId = '',
    this.jobTitle = 'Trabajo',
    this.jobStatus = ChatThreadStatus.active,
    this.agreedPrice = 0,
    this.counterpartName = '',
    this.counterpartAvatarUrl,
    this.category,
    this.workerId,
    this.isArchived = false,
    this.getThreadMessagesUseCase,
    this.sendMessageUseCase,
    super.key,
  });

  final String threadId;
  final String jobId;
  final String jobTitle;
  final ChatThreadStatus jobStatus;
  final double agreedPrice;
  final String counterpartName;
  final String? counterpartAvatarUrl;
  final String? category;
  final String? workerId;
  final bool isArchived;
  final GetThreadMessagesUseCase? getThreadMessagesUseCase;
  final SendMessageUseCase? sendMessageUseCase;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  GetThreadMessagesUseCase get _getThreadMessagesUseCase =>
      widget.getThreadMessagesUseCase ?? MessagesDependencies.getThreadMessages;
  SendMessageUseCase get _sendMessageUseCase =>
      widget.sendMessageUseCase ?? MessagesDependencies.sendMessage;

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(value.year, value.month, value.day);
    final diff = today.difference(messageDay).inDays;
    final timeStr =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return timeStr;
    if (diff == 1) return 'Ayer $timeStr';
    return '${value.day}/${value.month}/${value.year} $timeStr';
  }

  final controller = TextEditingController();
  final RealtimeService _realtime = RealtimeService.instance;
  bool _loading = true;
  bool _isOffline = false;
  bool _shouldRedirectToLogin = false;
  String? _error;
  List<ChatMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.joinThread(widget.threadId);
    _realtime.on('message.new', _onMessageNew);
    _load();
  }

  @override
  void dispose() {
    _realtime.off('message.new', _onMessageNew);
    controller.dispose();
    super.dispose();
  }

  void _onMessageNew(dynamic payload) {
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    final threadId = map['threadId']?.toString();
    if (threadId != widget.threadId) {
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _getThreadMessagesUseCase(threadId: widget.threadId);
    if (!mounted) return;

    result.fold(
      onSuccess: (messages) {
        setState(() {
          _messages = messages;
          _isOffline = false;
          _shouldRedirectToLogin = false;
          _loading = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _error = failure.message;
          _isOffline = failure is NetworkFailure;
          _shouldRedirectToLogin = failure is UnauthorizedFailure;
          _loading = false;
        });
      },
    );
  }

  Future<void> _send() async {
    final user = SessionStore.currentUser;
    final content = controller.text.trim();
    if (user == null || content.isEmpty || widget.isArchived) {
      return;
    }

    final result = await _sendMessageUseCase(
      threadId: widget.threadId,
      senderUserId: user.id,
      content: content,
    );

    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        controller.clear();
        _load();
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Color _statusColor(ChatThreadStatus status) {
    switch (status) {
      case ChatThreadStatus.active:
        return AppTheme.colorSuccess;
      case ChatThreadStatus.completed:
        return AppTheme.colorPrimary;
      case ChatThreadStatus.cancelled:
        return AppTheme.colorError;
    }
  }

  String _statusLabel(ChatThreadStatus status) {
    switch (status) {
      case ChatThreadStatus.active:
        return 'Activo';
      case ChatThreadStatus.completed:
        return 'Completado';
      case ChatThreadStatus.cancelled:
        return 'Cancelado';
    }
  }

  void _rehire() {
    if (widget.workerId == null || widget.category == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestFormScreen(
          initialPrompt: 'Volver a contratar: ${widget.jobTitle}',
          preselectedCategory: widget.category,
          preselectedWorkerId: widget.workerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SessionStore.currentUser?.id;

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and counterpart info
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: widget.counterpartAvatarUrl == null
                          ? null
                          : NetworkImage(widget.counterpartAvatarUrl!),
                      child: widget.counterpartAvatarUrl == null
                          ? Text(
                              widget.counterpartName
                                  .substring(0, 1)
                                  .toUpperCase(),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.counterpartName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.isArchived
                                ? 'Conversacion archivada'
                                : 'Activo ahora',
                            style: TextStyle(
                              color: widget.isArchived
                                  ? AppTheme.colorMuted
                                  : AppTheme.colorSuccess,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),

              // Sticky Job Summary Header
              GlassCard(
                borderRadius: 16,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.jobTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(
                                widget.jobStatus,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _statusLabel(widget.jobStatus),
                              style: TextStyle(
                                color: _statusColor(widget.jobStatus),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Bs ${widget.agreedPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppTheme.colorPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatDate(DateTime.now()),
                            style: const TextStyle(
                              color: AppTheme.colorMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              if (_isOffline)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Sin conexion.',
                    style: TextStyle(color: AppTheme.colorMuted),
                  ),
                ),

              if (_shouldRedirectToLogin)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Sesion expirada.',
                    style: TextStyle(color: AppTheme.colorError),
                  ),
                ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];

                          if (message.isSystem) {
                            return _buildSystemMessage(message);
                          }

                          final mine = message.senderUserId == currentUserId;
                          return _buildTextMessage(message, mine);
                        },
                      ),
              ),

              // Rehire button for archived chats
              if (widget.isArchived &&
                  widget.workerId != null &&
                  widget.category != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ChambaPrimaryButton(
                    label: 'Volver a contratar',
                    onPressed: _rehire,
                  ),
                ),

              // Message input (disabled for archived chats)
              if (!widget.isArchived)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GlassCard(
                    borderRadius: 30,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Escribe un mensaje...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.colorPrimary,
                          child: IconButton(
                            onPressed: _send,
                            icon: const Icon(
                              Icons.send,
                              color: AppTheme.colorTextOnPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: GlassCard(
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              message.displayContent,
              style: TextStyle(
                color: AppTheme.colorMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextMessage(ChatMessage message, bool mine) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: mine ? AppTheme.colorPrimary : AppTheme.colorSurfaceSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                message.content ?? '',
                style: TextStyle(
                  fontSize: 17,
                  color: mine ? Colors.white : AppTheme.colorText,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(message.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: mine
                    ? AppTheme.colorPrimary.withValues(alpha: 0.75)
                    : AppTheme.colorMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
