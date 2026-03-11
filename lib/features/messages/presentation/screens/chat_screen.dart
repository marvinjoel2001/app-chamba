import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.threadId,
    required this.title,
    this.avatarUrl,
    super.key,
  });

  final String threadId;
  final String title;
  final String? avatarUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '--';
    }
    final normalized = value.replaceFirst('T', ' ');
    return normalized.length > 16 ? normalized.substring(0, 16) : normalized;
  }

  final controller = TextEditingController();
  final RealtimeService _realtime = RealtimeService.instance;
  bool _loading = true;
  String? _error;
  List<dynamic> _messages = const [];

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

    try {
      final response = await MobileBackendService.threadMessages(
        threadId: widget.threadId,
      );
      setState(() {
        _messages = (response['messages'] as List<dynamic>? ?? const []);
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final user = SessionStore.currentUser;
    final content = controller.text.trim();
    if (user == null || content.isEmpty) {
      return;
    }

    try {
      await MobileBackendService.sendMessage(
        threadId: widget.threadId,
        senderUserId: user.id,
        content: content,
      );
      controller.clear();
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SessionStore.currentUser?.id;

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: widget.avatarUrl == null
                          ? null
                          : NetworkImage(widget.avatarUrl!),
                      child: widget.avatarUrl == null
                          ? Text(widget.title.substring(0, 1).toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'Activo ahora',
                            style: TextStyle(color: AppTheme.colorPrimary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.call_outlined),
                    ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
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
                          final message =
                              _messages[index] as Map<String, dynamic>;
                          final mine = message['senderUserId'] == currentUserId;

                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: mine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? AppTheme.colorPrimary
                                          : AppTheme.colorSurfaceSoft,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Text(
                                      message['content']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: mine
                                            ? Colors.white
                                            : AppTheme.colorText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(
                                      message['createdAt']?.toString(),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mine
                                          ? AppTheme.colorPrimary.withValues(
                                              alpha: 0.75,
                                            )
                                          : AppTheme.colorMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
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
                          icon: const Icon(Icons.send),
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
}
