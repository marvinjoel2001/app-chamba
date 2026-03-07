import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final messages = <_ChatMessage>[
    const _ChatMessage(
      text: 'Hola! Vi tu solicitud para reparar la tuberia de cocina.',
      time: '09:15',
      mine: false,
    ),
    const _ChatMessage(
      text: 'Genial Marco, te queda bien 3:00 PM?',
      time: '09:18',
      mine: true,
    ),
    const _ChatMessage(
      text: 'Perfecto, podrias compartir la direccion exacta?',
      time: '09:20',
      mine: false,
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    const CircleAvatar(
                      radius: 22,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Marco Antonio',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Activo ahora - Especialista',
                            style: TextStyle(color: AppTheme.colorPrimary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.call)),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Align(
                      alignment:
                          message.mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(16),
                        constraints: const BoxConstraints(maxWidth: 360),
                        decoration: BoxDecoration(
                          color: message.mine
                              ? AppTheme.colorPrimary
                              : AppTheme.colorSurfaceSoft,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: message.mine
                              ? const [
                                  BoxShadow(
                                    color: Color(0x447A2BC4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.text,
                              style: TextStyle(
                                fontSize: 18,
                                color: message.mine ? Colors.white : AppTheme.colorText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message.time,
                              style: TextStyle(
                                color: message.mine
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
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.emoji_emotions_outlined),
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.colorPrimary,
                      child: IconButton(
                        onPressed: () {
                          if (controller.text.trim().isEmpty) {
                            return;
                          }
                          setState(() {
                            messages.add(
                              _ChatMessage(
                                text: controller.text.trim(),
                                time: 'Ahora',
                                mine: true,
                              ),
                            );
                            controller.clear();
                          });
                        },
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

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.time,
    required this.mine,
  });

  final String text;
  final String time;
  final bool mine;
}

