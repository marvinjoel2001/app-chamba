import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../offers/presentation/screens/offers_screen.dart';
import '../../../request/presentation/screens/incoming_request_screen.dart';
import '../../../worker/presentation/screens/radar_screen.dart';
import '../../../worker/presentation/screens/worker_history_screen.dart';
import '../../../worker/presentation/screens/profile_menu_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({required this.role, super.key});

  final String role;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int currentIndex = 0;
  final RealtimeService _realtime = RealtimeService.instance;

  // Índice de la pestaña de mensajes según el rol
  int get _messagesTabIndex => widget.role == 'worker' ? 2 : 2;

  @override
  void initState() {
    super.initState();
    _realtime.on('message.new', _onMessageNew);
  }

  @override
  void dispose() {
    _realtime.off('message.new', _onMessageNew);
    super.dispose();
  }

  void _onMessageNew(dynamic payload) {
    // Solo incrementar si el mensaje es de otro usuario y no estamos en la pestaña de mensajes
    final myId = SessionStore.currentUser?.id;
    final map = payload is Map ? payload : <dynamic, dynamic>{};
    final senderUserId = map['message']?['senderUserId']?.toString();

    // No contar mensajes propios
    if (senderUserId == myId) return;

    // Si ya estamos en la pestaña de mensajes, no incrementar
    if (currentIndex == _messagesTabIndex) return;

    UnreadMessagesNotifier.instance.increment();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.role == 'worker'
        ? const [
            IncomingRequestScreen(),
            RadarScreen(),
            MessagesScreen(),
            WorkerHistoryScreen(),
            ProfileMenuScreen(),
          ]
        : [
            ExploreScreen(role: widget.role),
            const OffersScreen(),
            const MessagesScreen(),
            const ProfileMenuScreen(),
          ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: UnreadMessagesNotifier.instance,
        builder: (context, unreadCount, _) {
          return _ChambaBottomNavWithBadge(
            role: widget.role,
            currentIndex: currentIndex,
            unreadCount: unreadCount,
            messagesTabIndex: _messagesTabIndex,
            onTap: (index) {
              // Al tocar mensajes, resetear badge
              if (index == _messagesTabIndex) {
                UnreadMessagesNotifier.instance.reset();
              }
              setState(() => currentIndex = index);
            },
          );
        },
      ),
    );
  }
}

/// Bottom nav con soporte de badge en la pestaña de mensajes
class _ChambaBottomNavWithBadge extends StatelessWidget {
  const _ChambaBottomNavWithBadge({
    required this.role,
    required this.currentIndex,
    required this.unreadCount,
    required this.messagesTabIndex,
    required this.onTap,
  });

  final String role;
  final int currentIndex;
  final int unreadCount;
  final int messagesTabIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // Reutilizamos ChambaBottomNav pero necesitamos inyectar el badge
    // Lo hacemos con un Stack sobre el ícono de mensajes
    return ChambaBottomNavWithBadge(
      role: role,
      currentIndex: currentIndex,
      unreadCount: unreadCount,
      messagesTabIndex: messagesTabIndex,
      onTap: onTap,
    );
  }
}
