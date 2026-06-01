import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../domain/entities/chat_thread.dart';
import '../state/messages_dependencies.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final RealtimeService _realtime = RealtimeService.instance;

  bool _loading = true;
  bool _isOffline = false;
  bool _shouldRedirectToLogin = false;
  String? _error;
  List<ChatThread> _threads = const [];

  @override
  void initState() {
    super.initState();
    UnreadMessagesNotifier.instance.reset();
    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.on('message.new', _onMessageEvent);
    _load();
  }

  @override
  void dispose() {
    _realtime.off('message.new', _onMessageEvent);
    super.dispose();
  }

  void _onMessageEvent(dynamic payload) {
    _load();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(value.year, value.month, value.day);
    final diff = today.difference(messageDay).inDays;
    final timeStr =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return timeStr;
    if (diff == 1) return 'Ayer';
    return '${value.day}/${value.month}';
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesion expirada';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    // Cargar todos los threads (activos y archivados) en una sola lista
    final activeResult = await MessagesDependencies.getActiveThreads(
      userId: user.id,
      type: ChatThreadType.active,
    );
    final archivedResult = await MessagesDependencies.getArchivedThreads(
      userId: user.id,
      type: ChatThreadType.archived,
    );

    if (!mounted) return;

    final List<ChatThread> allThreads = [];

    activeResult.fold(
      onSuccess: (threads) {
        allThreads.addAll(threads);
        _isOffline = false;
        _shouldRedirectToLogin = false;
      },
      onFailure: (failure) {
        _isOffline = failure is NetworkFailure;
        _shouldRedirectToLogin = failure is UnauthorizedFailure;
      },
    );

    archivedResult.fold(
      onSuccess: (threads) {
        allThreads.addAll(threads);
      },
      onFailure: (failure) {
        if (_error == null) _error = failure.message;
      },
    );

    // Ordenar por fecha del último mensaje (más reciente primero)
    allThreads.sort((a, b) {
      final aDate = a.lastMessageAt ?? a.createdAt;
      final bDate = b.lastMessageAt ?? b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    setState(() {
      _threads = allThreads;
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Mensajes',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh, color: theme.iconTheme.color),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isOffline)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Sin conexion. Mostrando datos locales.',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              ),
            if (_shouldRedirectToLogin)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Sesion expirada. Inicia sesion nuevamente.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            Expanded(
              child: _buildThreadList(_threads, isLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreadList(List<ChatThread> threads, bool isLight) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && threads.isEmpty) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
      );
    }
    if (threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No tienes conversaciones aun.',
            style: TextStyle(
                color: isLight ? Colors.grey[600] : AppTheme.colorMuted),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: threads.length,
      itemBuilder: (context, index) {
        final thread = threads[index];
        return _buildWhatsAppThreadItem(thread, isLight);
      },
    );
  }

  Widget _buildWhatsAppThreadItem(ChatThread thread, bool isLight) {
    final currentUser = SessionStore.currentUser;
    final isWorker = currentUser?.type == 'worker';

    // Worker ve foto del trabajo, cliente ve foto del worker
    final String? avatarUrl =
        isWorker ? null : thread.counterpartProfilePhotoUrl;

    final String avatarText = isWorker
        ? (thread.jobTitle.isNotEmpty ? thread.jobTitle[0] : 'T')
        : (thread.counterpartName.isNotEmpty ? thread.counterpartName[0] : '?');

    final bool hasUnread = thread.hasUnreadMessages;
    const Color unreadColor = Color(0xFF25D366);

    // Colores según el tema
    final highlightBg = isLight
        ? const Color(0xFFE8F5E9)
        : const Color.fromRGBO(255, 255, 255, 0.08);
    final borderC = isLight
        ? const Color(0xFFE0E0E0)
        : const Color.fromRGBO(255, 255, 255, 0.1);
    final textC = isLight ? const Color(0xFF1E293B) : Colors.white;
    final mutedC = isLight
        ? const Color(0xFF64748B)
        : const Color.fromRGBO(255, 255, 255, 0.7);
    final secondaryC = isLight
        ? const Color(0xFF475569)
        : const Color.fromRGBO(255, 255, 255, 0.5);

    return InkWell(
      onTap: () => _openChat(thread),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasUnread ? highlightBg : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: borderC,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar circular
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isWorker
                    ? AppTheme.colorPrimary.withValues(alpha: 0.2)
                    : AppTheme.colorSuccess.withValues(alpha: 0.2),
                image: avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl == null
                  ? Center(
                      child: Text(
                        avatarText.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primera fila: Nombre del trabajo y fecha
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.jobTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(thread.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? unreadColor : mutedC,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Segunda fila: Nombre de la otra persona
                  Text(
                    isWorker
                        ? 'Cliente: ${thread.counterpartName}'
                        : 'Worker: ${thread.counterpartName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedC,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Tercera fila: Ultimo mensaje + badge no leidos
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessage ?? 'Sin mensajes',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasUnread ? textC : secondaryC,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: unreadColor,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(width: 4, height: 4),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(ChatThread thread) {
    SessionStore.activeThreadId = thread.id;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          threadId: thread.id,
          jobId: thread.jobId,
          jobTitle: thread.jobTitle,
          jobStatus: thread.jobStatus,
          agreedPrice: thread.agreedPrice,
          counterpartName: thread.counterpartName,
          counterpartAvatarUrl: thread.counterpartProfilePhotoUrl,
          category: thread.category,
          workerId: thread.workerId,
          isArchived: thread.isArchived,
        ),
      ),
    );
  }
}
