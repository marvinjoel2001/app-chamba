import 'package:flutter/material.dart';

import '../../../../core/widgets/chamba_widgets.dart';
import '../../../request/presentation/screens/incoming_request_screen.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Mensajes',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(
                      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
                    ),
                  ),
                  title: const Text('Marco Antonio'),
                  subtitle: const Text('Hola! Vi tu solicitud de plomeria...'),
                  trailing: const Text('09:20'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(
                      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
                    ),
                  ),
                  title: const Text('Ricardo Gomez'),
                  subtitle: const Text('Llego en 23 min. Estoy en camino.'),
                  trailing: const Text('Ayer'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
                    );
                  },
                ),
              ),
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
