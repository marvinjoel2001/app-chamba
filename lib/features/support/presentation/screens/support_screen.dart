import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

/// Reason options shown to the user when reporting a problem.
const _reasons = [
  _ReasonOption(
    icon: Icons.money_off,
    title: 'Problema con el cobro',
    description: 'El monto acordado no coincide o hubo un cobro indebido',
  ),
  _ReasonOption(
    icon: Icons.person_off,
    title: 'Trabajador no se presentó',
    description: 'Aceptó el trabajo pero nunca llegó al lugar',
  ),
  _ReasonOption(
    icon: Icons.construction,
    title: 'Trabajo mal realizado',
    description: 'La calidad del servicio no fue la esperada',
  ),
  _ReasonOption(
    icon: Icons.warning_amber,
    title: 'Comportamiento inadecuado',
    description: 'Falta de respeto, acoso o conducta inapropiada',
  ),
  _ReasonOption(
    icon: Icons.help_outline,
    title: 'Otro problema',
    description: 'Mi problema no aparece en las opciones anteriores',
  ),
];

class _ReasonOption {
  const _ReasonOption({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// Entry point: shows reason picker → then opens chat with support.
class SupportScreen extends StatefulWidget {
  const SupportScreen({
    this.requestId,
    this.reportedUserId,
    super.key,
  });

  final String? requestId;
  final String? reportedUserId;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String? _disputeId;
  String? _selectedReason;

  Future<void> _submitReason(String reason) async {
    final user = SessionStore.currentUser;
    final requestId = widget.requestId ?? SessionStore.activeRequestId;
    if (user == null) {
      return;
    }

    setState(() => _selectedReason = reason);

    try {
      final result = await MobileBackendService.instance.createDispute(
        requestId: requestId,
        reportedBy: user.id,
        reportedUser: widget.reportedUserId,
        reason: reason,
      );
      final disputeId = result['dispute']?['id']?.toString();
      if (disputeId == null) throw Exception('No se pudo crear el reporte');

      // Send initial automated message
      await MobileBackendService.instance.sendDisputeMessage(
        disputeId: disputeId,
        senderType: 'user',
        senderId: user.id,
        content: 'Hola, tengo un problema: $reason',
      );

      if (!mounted) return;
      setState(() => _disputeId = disputeId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _selectedReason = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_disputeId != null) {
      return _SupportChatView(
        disputeId: _disputeId!,
        reason: _selectedReason ?? '',
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Reportar un problema'),
      ),
      body: ChambaBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '¿Qué problema tienes?',
                style: TextStyle(
                  color: AppTheme.colorText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona la opción que mejor describa tu situación.',
                style: TextStyle(color: AppTheme.colorMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ..._reasons.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.15),
                        child: Icon(r.icon, color: AppTheme.colorPrimary, size: 22),
                      ),
                      title: Text(
                        r.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        r.description,
                        style: const TextStyle(
                          color: AppTheme.colorMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: _selectedReason == r.title
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.chevron_right,
                              color: AppTheme.colorMuted,
                            ),
                      onTap: _selectedReason != null
                          ? null
                          : () => _submitReason(r.title),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chat view with support after selecting a reason.
class _SupportChatView extends StatefulWidget {
  const _SupportChatView({
    required this.disputeId,
    required this.reason,
  });

  final String disputeId;
  final String reason;

  @override
  State<_SupportChatView> createState() => _SupportChatViewState();
}

class _SupportChatViewState extends State<_SupportChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final result = await MobileBackendService.instance.getDisputeMessages(
        disputeId: widget.disputeId,
      );
      final msgs = (result['messages'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final user = SessionStore.currentUser;
    if (user == null) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await MobileBackendService.instance.sendDisputeMessage(
        disputeId: widget.disputeId,
        senderType: 'user',
        senderId: user.id,
        content: text,
      );
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = SessionStore.currentUser?.id;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.colorBackgroundAccent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Soporte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.reason,
              style: const TextStyle(
                color: AppTheme.colorMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.colorPrimary.withValues(alpha: 0.1),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.colorPrimary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Un agente de soporte revisará tu caso pronto.',
                    style: TextStyle(color: AppTheme.colorMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Escribe tu mensaje para iniciar la conversación.',
                          style: TextStyle(color: AppTheme.colorMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final isMe = msg['senderId'] == userId;
                          final senderName =
                              msg['senderName']?.toString() ?? 'Soporte';
                          final content = msg['content']?.toString() ?? '';
                          final time = DateTime.tryParse(
                            msg['createdAt']?.toString() ?? '',
                          );

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppTheme.colorPrimary.withValues(alpha: 0.2)
                                    : AppTheme.colorSurfaceSoft,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe
                                      ? const Radius.circular(16)
                                      : const Radius.circular(4),
                                  bottomRight: isMe
                                      ? const Radius.circular(4)
                                      : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        senderName,
                                        style: const TextStyle(
                                          color: AppTheme.colorPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    content,
                                    style: const TextStyle(
                                      color: AppTheme.colorText,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (time != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          color: AppTheme.colorMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: 8 + bottomPad,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.colorBackgroundAccent,
              border: Border(
                top: BorderSide(color: Color(0xFF2A2A3A)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppTheme.colorText),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      hintStyle: const TextStyle(color: AppTheme.colorMuted),
                      filled: true,
                      fillColor: AppTheme.colorSurfaceSoft,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppTheme.colorPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _sending ? null : _send,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
