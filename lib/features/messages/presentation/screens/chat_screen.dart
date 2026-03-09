import 'package:flutter/material.dart';

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
  bool _loading = true;
  String? _error;
  List<dynamic> _messages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await MobileBackendService.threadMessages(threadId: widget.threadId);
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
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          widget.avatarUrl == null ? null : NetworkImage(widget.avatarUrl!),
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
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                          ),
                          const Text(
                            'Activo ahora',
                            style: TextStyle(color: AppTheme.colorPrimary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!))
                        : ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index] as Map<String, dynamic>;
                              final mine = message['senderUserId'] == currentUserId;

                              return Align(
                                alignment:
                                    mine ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(16),
                                  constraints: const BoxConstraints(maxWidth: 360),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? AppTheme.colorPrimary
                                        : AppTheme.colorSurfaceSoft,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message['content']?.toString() ?? '',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color:
                                              mine ? Colors.white : AppTheme.colorText,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatDate(message['createdAt']?.toString()),
                                        style: TextStyle(
                                          color: mine
                                              ? Colors.white.withValues(alpha: 0.75)
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
              GlassCard(
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

