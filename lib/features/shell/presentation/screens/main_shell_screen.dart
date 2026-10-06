import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/services/worker_background_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/session/unread_notifications_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
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
  final Set<int> _visitedIndices = {0};
  final RealtimeService _realtime = RealtimeService.instance;

  // Worker: [Inicio(0), Billetera(1), Mensajes(2), Perfil(3)]
  // Client: [Inicio(0), Mensajes(1), Perfil(2)]
  int get _messagesTabIndex => widget.role == 'worker' ? 2 : 1;

  @override
  void initState() {
    super.initState();

    _realtime.on('user.verification.updated', _onVerificationUpdated);



    // Iniciar servicio de background para workers automáticamente
    if (widget.role == 'worker') {
      WorkerBackgroundService.setEnabled(SessionStore.currentUser?.isAvailable ?? false);
      // El banner de solicitud nueva vive en el shell, no en la pestaña de
      // solicitudes: el worker puede estar en Mensajes o Perfil cuando entra.

    }
    
    // Iniciar polling de notificaciones no leidas
    UnreadNotificationsNotifier.instance;
    UnreadMessagesNotifier.instance.refresh();
  }

  @override
  void dispose() {
    _realtime.off('user.verification.updated', _onVerificationUpdated);
    super.dispose();
  }

  Future<void> _onVerificationUpdated(dynamic payload) async {
    final currentUser = SessionStore.currentUser;
    if (currentUser == null) {
      return;
    }

    final data = payload is Map
        ? Map<String, dynamic>.from(payload as Map)
        : <String, dynamic>{};
    final nextVerificationStatus = data['verificationStatus']?.toString() ??
        currentUser.verificationStatus;
    final hasIdDecision = data.containsKey('idPhotoVerified');
    final hasFaceDecision = data.containsKey('facePhotoVerified');

    final updatedUser = SessionUser(
      id: currentUser.id,
      type: currentUser.type,
      firstName: currentUser.firstName,
      lastName: currentUser.lastName,
      email: currentUser.email,
      phone: currentUser.phone,
      profilePhotoUrl: currentUser.profilePhotoUrl,
      verificationStatus: nextVerificationStatus,
      idPhotoUrl: data['idPhotoUrl']?.toString() ?? currentUser.idPhotoUrl,
      facePhotoUrl:
          data['facePhotoUrl']?.toString() ?? currentUser.facePhotoUrl,
      idPhotoVerified: hasIdDecision
          ? data['idPhotoVerified'] as bool?
          : currentUser.idPhotoVerified,
      facePhotoVerified: hasFaceDecision
          ? data['facePhotoVerified'] as bool?
          : currentUser.facePhotoVerified,
      isBlocked: currentUser.isBlocked,
      isAvailable: currentUser.isAvailable,
      isAgencyWorker: currentUser.isAgencyWorker,
    );

    await SessionStore.setCurrentUser(updatedUser);


  }

  @override
  Widget build(BuildContext context) {
    final isWorker = widget.role == 'worker';
    final pages = isWorker
        ? [
            IncomingRequestScreen(isActive: currentIndex == 0),
            const WalletScreen(),
            const MessagesScreen(),
            const ProfileMenuScreen(),
          ]
        : [
            ExploreScreen(role: widget.role),
            const MessagesScreen(),
            const ProfileMenuScreen(),
          ];

    if (currentIndex >= pages.length) {
      currentIndex = pages.length - 1;
    }

    // Detectar si está en la pestaña de mensajes
    final isOnMessagesTab = currentIndex == _messagesTabIndex;

    // Tema claro para mensajes, oscuro para el resto
    final theme = isOnMessagesTab ? AppTheme.light() : AppTheme.dark();

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(
          index: currentIndex,
          children: List.generate(
            pages.length,
            (i) => _visitedIndices.contains(i)
                ? pages[i]
                : const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: UnreadMessagesNotifier.instance,
          builder: (context, unreadCount, _) {
            return ChambaBottomNavWithBadge(
              role: widget.role,
              currentIndex: currentIndex,
              unreadCount: unreadCount,
              messagesTabIndex: _messagesTabIndex,
              isLightTheme: isOnMessagesTab,
              onTap: (index) {
                if (index == _messagesTabIndex) {
                  UnreadMessagesNotifier.instance.refresh();
                }
                setState(() {
                  currentIndex = index;
                  _visitedIndices.add(index);
                });
              },
            );
          },
        ),
      ),
    );
  }
}
