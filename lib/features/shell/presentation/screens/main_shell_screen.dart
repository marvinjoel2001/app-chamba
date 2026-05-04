import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../offers/presentation/screens/offers_screen.dart';
import '../../../request/presentation/screens/incoming_request_screen.dart';
import '../../../worker/presentation/screens/wallet_screen.dart';
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

  // Worker: [Inicio(0), Billetera(1), Mensajes(2), Perfil(3)]
  // Client: [Inicio(0), Ofertas(1), Mensajes(2), Perfil(3)]
  int get _messagesTabIndex => 2;

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
    final myId = SessionStore.currentUser?.id;
    final map = payload is Map ? payload : <dynamic, dynamic>{};
    final senderUserId = map['message']?['senderUserId']?.toString();
    if (senderUserId == myId) return;
    if (currentIndex == _messagesTabIndex) return;
    UnreadMessagesNotifier.instance.increment();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.role == 'worker'
        ? const [
            IncomingRequestScreen(),
            WalletScreen(),
            MessagesScreen(),
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
          return ChambaBottomNavWithBadge(
            role: widget.role,
            currentIndex: currentIndex,
            unreadCount: unreadCount,
            messagesTabIndex: _messagesTabIndex,
            onTap: (index) {
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
