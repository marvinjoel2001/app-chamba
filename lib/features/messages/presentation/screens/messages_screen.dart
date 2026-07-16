import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../domain/entities/chat_thread.dart';
import '../../../../core/session/unread_notifications_notifier.dart';
import '../../../notifications/data/notifications_service.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
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
    // Refresco silencioso: no mostrar spinner cuando llega un mensaje nuevo.
    _load(silent: true);
  }

  Future<void> _loadNotifications() async {
    // Ya no cargamos localmente la lista de notificaciones para contar las no leídas,
    // el UnreadNotificationsNotifier se encarga de esto.
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

  Future<void> _load({bool silent = false}) async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesion expirada';
        _loading = false;
      });
      return;
    }
    // Solo spinner en la carga inicial; los refrescos son silenciosos.
    if (!silent || _threads.isEmpty) {
      setState(() {
        _loading = _threads.isEmpty;
        _error = null;
      });
    }

    _loadNotifications();

    // Cargar threads activos y archivados en paralelo
    final results = await Future.wait([
      MessagesDependencies.getActiveThreads(
        userId: user.id,
        type: ChatThreadType.active,
      ),
      MessagesDependencies.getArchivedThreads(
        userId: user.id,
        type: ChatThreadType.archived,
      ),
    ]);
    final activeResult = results[0];
    final archivedResult = results[1];

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
        _error ??= failure.message;
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

  Future<void> _deleteThread(ChatThread thread) async {
    final user = SessionStore.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar chat'),
        content: const Text(
            '¿Deseas eliminar esta conversación? Solo se eliminará de tu bandeja de entrada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.colorMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppTheme.colorError)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await MessagesDependencies.deleteThread(
      threadId: thread.id,
      userId: user.id,
    );

    result.fold(
      onSuccess: (_) {
        setState(() {
          _threads.removeWhere((t) => t.id == thread.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat eliminado')),
          );
        }
      },
      onFailure: (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar chat: ${failure.message}')),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFD),
        elevation: 0,
        title: const Text(
          'Mensajes',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF090D16),
          ),
        ),
        actions: [
          const SizedBox(width: 8),
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
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Text(
                  'No tienes conversaciones aun.',
                  style: TextStyle(
                      color: isLight ? Colors.grey[600] : AppTheme.colorMuted),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildNotificationsItem(isLight),
        const SizedBox(height: 32),
        _buildDivider(),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: threads.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: Color(0xFFF3F4F6),
              indent: 76,
            ),
            itemBuilder: (context, index) {
              return _buildWhatsAppThreadItem(threads[index], isLight);
            },
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFE5E7EB))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'CHATS',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFFE5E7EB))),
      ],
    );
  }

  Widget _buildNotificationsItem(bool isLight) {
    return ValueListenableBuilder<int>(
      valueListenable: UnreadNotificationsNotifier.instance,
      builder: (context, unreadCount, child) {
        final hasUnread = unreadCount > 0;
        const Color unreadColor = Colors.redAccent;

        return InkWell(
          onTap: () async {
            UnreadNotificationsNotifier.instance.markAllAsRead();
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.1),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.notifications,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notificaciones',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hasUnread
                                  ? 'Tienes $unreadCount notificaciones nuevas'
                                  : 'No hay notificaciones nuevas',
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF6B7280), // Gray 500
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.colorPrimary,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWhatsAppThreadItem(ChatThread thread, bool isLight) {
    // Foto del trabajo por defecto
    const AssetImage jobAvatar = AssetImage('assets/images/chat/default_job.png');

    // Conteo real de mensajes no leídos que envía el backend.
    final int unreadCount = thread.unreadCount;
    final bool hasUnread = unreadCount > 0;
    final String unreadLabel = unreadCount > 99 ? '99+' : '$unreadCount';

    final highlightBg = const Color(0xFFF8F7FA); // Light purple/grey on hover/unread
    final textC = const Color(0xFF090D16); // Dark text
    final mutedC = const Color(0xFF6B7280); // Gray text

    return InkWell(
      onTap: () => _openChat(thread),
      onLongPress: () => _deleteThread(thread),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread ? highlightBg : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar circular del trabajo
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: jobAvatar,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Indicador de conexión (Punto verde)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.colorSuccess,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

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
                          thread.jobTitle.isNotEmpty ? thread.jobTitle : thread.counterpartName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textC,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(thread.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? AppTheme.colorPrimary : mutedC,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Segunda fila: Categoría
                  if (thread.category != null && thread.category!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.colorPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        thread.category!,
                        style: const TextStyle(
                          color: AppTheme.colorPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Tercera fila: Ultimo mensaje + badge no leídos
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessage ?? 'Sin mensajes',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasUnread ? textC : mutedC,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
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
                            color: AppTheme.colorPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          threadId: thread.id,
          jobId: thread.jobId,
          jobTitle: thread.jobTitle,
          jobStatus: thread.jobStatus,
          agreedPrice: thread.agreedPrice,
          counterpartName: thread.counterpartName,
          counterpartId: SessionStore.currentUser?.type == 'worker'
              ? thread.clientId
              : thread.workerId,
          counterpartAvatarUrl: thread.counterpartProfilePhotoUrl,
          counterpartPhone: thread.counterpartPhone,
          category: thread.category,
          workerId: thread.workerId,
          isArchived: thread.isArchived,
        ),
      ),
    )
        .then((_) {
      // Al volver del chat, refresca para reflejar los mensajes ya leídos.
      if (mounted) _load(silent: true);
    });
  }
}
