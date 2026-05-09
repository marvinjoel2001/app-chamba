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

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final RealtimeService _realtime = RealtimeService.instance;
  late TabController _tabController;

  bool _loading = true;
  bool _isOffline = false;
  bool _shouldRedirectToLogin = false;
  String? _error;
  List<ChatThread> _activeThreads = const [];
  List<ChatThread> _archivedThreads = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    UnreadMessagesNotifier.instance.reset();
    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.on('message.new', _onMessageEvent);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _realtime.off('message.new', _onMessageEvent);
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _load();
    }
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

    final activeResult = await MessagesDependencies.getActiveThreads(
      userId: user.id,
      type: ChatThreadType.active,
    );
    final archivedResult = await MessagesDependencies.getArchivedThreads(
      userId: user.id,
      type: ChatThreadType.archived,
    );

    if (!mounted) return;

    activeResult.fold(
      onSuccess: (threads) {
        setState(() {
          _activeThreads = threads;
          _isOffline = false;
          _shouldRedirectToLogin = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _isOffline = failure is NetworkFailure;
          _shouldRedirectToLogin = failure is UnauthorizedFailure;
        });
      },
    );

    archivedResult.fold(
      onSuccess: (threads) {
        setState(() {
          _archivedThreads = threads;
          _loading = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _loading = false;
          if (_error == null) _error = failure.message;
        });
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
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Mensajes',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Activos'),
                  Tab(text: 'Historial'),
                ],
              ),
              if (_isOffline)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Sin conexion. Mostrando datos locales.',
                    style: TextStyle(color: AppTheme.colorMuted),
                  ),
                ),
              if (_shouldRedirectToLogin)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Sesion expirada. Inicia sesion nuevamente.',
                    style: TextStyle(color: AppTheme.colorError),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildThreadList(_activeThreads),
                    _buildThreadList(_archivedThreads, isArchived: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreadList(List<ChatThread> threads, {bool isArchived = false}) {
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
            isArchived
                ? 'No hay conversaciones archivadas.'
                : 'Aun no hay conversaciones activas.',
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: threads.length,
      itemBuilder: (context, index) {
        final thread = threads[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            child: InkWell(
              onTap: () => _openChat(thread),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                thread.jobTitle,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                thread.counterpartName,
                                style: const TextStyle(
                                  color: AppTheme.colorMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.colorPrimary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Bs ${thread.agreedPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: AppTheme.colorPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  thread.jobStatus,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                thread.statusLabel,
                                style: TextStyle(
                                  color: _statusColor(thread.jobStatus),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (thread.lastMessage != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              thread.lastMessage!,
                              style: const TextStyle(
                                color: AppTheme.colorMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatDate(thread.lastMessageAt),
                            style: const TextStyle(
                              color: AppTheme.colorMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
