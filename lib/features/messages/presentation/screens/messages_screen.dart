import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../request/presentation/screens/incoming_request_screen.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final RealtimeService _realtime = RealtimeService.instance;
  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '--';
    }
    final normalized = value.replaceFirst('T', ' ');
    return normalized.length > 16 ? normalized.substring(0, 16) : normalized;
  }

  bool _loading = true;
  String? _error;
  List<dynamic> _threads = const [];

  @override
  void initState() {
    super.initState();
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

    try {
      final response = await MobileBackendService.messages(userId: user.id);
      setState(() {
        _threads = (response['threads'] as List<dynamic>? ?? const []);
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    'Mensajes',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(_error!)
              else if (_threads.isEmpty)
                const Text('Aun no hay conversaciones.')
              else
                ..._threads.map((thread) {
                  final threadMap = thread as Map<String, dynamic>;
                  final counterpart =
                      threadMap['counterpart'] as Map<String, dynamic>? ?? {};

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundImage:
                              counterpart['profilePhotoUrl'] == null
                              ? null
                              : NetworkImage(
                                  counterpart['profilePhotoUrl'] as String,
                                ),
                          child: counterpart['profilePhotoUrl'] == null
                              ? Text(
                                  (counterpart['firstName'] ?? 'U')
                                      .toString()
                                      .substring(0, 1),
                                )
                              : null,
                        ),
                        title: Text(
                          '${counterpart['firstName'] ?? ''} ${counterpart['lastName'] ?? ''}'
                              .trim(),
                        ),
                        subtitle: Text(
                          threadMap['lastMessage']?.toString() ?? '',
                        ),
                        trailing: Text(
                          _formatDate(threadMap['lastMessageAt']?.toString()),
                          textAlign: TextAlign.right,
                        ),
                        onTap: () {
                          SessionStore.activeThreadId =
                              threadMap['id'] as String?;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(
                                threadId: threadMap['id'] as String,
                                title:
                                    '${counterpart['firstName'] ?? ''} ${counterpart['lastName'] ?? ''}'
                                        .trim(),
                                avatarUrl:
                                    counterpart['profilePhotoUrl'] as String?,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 18),
              ChambaPrimaryButton(
                label: 'Abrir solicitud entrante demo',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const IncomingRequestScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
