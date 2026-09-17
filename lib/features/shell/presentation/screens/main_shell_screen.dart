import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/services/new_request_alert.dart';
import '../../../../core/services/sound_effect_service.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../core/services/worker_background_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/session/unread_notifications_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../../core/widgets/confetti_celebration.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../request/presentation/screens/incoming_request_screen.dart';
import '../../../request/presentation/screens/job_in_progress_screen.dart';
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
    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);

    _realtime.on('message.new', _onMessageNew);
    _realtime.on('user.verification.updated', _onVerificationUpdated);
    _realtime.on('offer.new', _onOfferNew);
    _realtime.on('offer.client_counter', _onOfferClientCounter);
    _realtime.on('offer.accepted', _onOfferAccepted);

    // Iniciar servicio de background para workers automáticamente
    if (widget.role == 'worker') {
      WorkerBackgroundService.setEnabled(true);
      // El banner de solicitud nueva vive en el shell, no en la pestaña de
      // solicitudes: el worker puede estar en Mensajes o Perfil cuando entra.
      NewRequestAlert.instance.lastEvent.addListener(_onNewRequestAlert);
    }
    
    // Iniciar polling de notificaciones no leidas
    UnreadNotificationsNotifier.instance;
  }

  @override
  void dispose() {
    _realtime.off('message.new', _onMessageNew);
    _realtime.off('user.verification.updated', _onVerificationUpdated);
    _realtime.off('offer.new', _onOfferNew);
    _realtime.off('offer.client_counter', _onOfferClientCounter);
    _realtime.off('offer.accepted', _onOfferAccepted);
    NewRequestAlert.instance.lastEvent.removeListener(_onNewRequestAlert);
    super.dispose();
  }

  void _onOfferAccepted(dynamic payload) {
    final myId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    final workerUserId = map['workerUserId']?.toString();
    final clientUserId = map['clientUserId']?.toString();

    if (myId == null || (myId != workerUserId && myId != clientUserId)) return;

    final requestId = map['requestId']?.toString();
    if (requestId != null) {
      SessionStore.activeRequestId = requestId;
    }

    if (widget.role == 'worker' && myId == workerUserId && requestId != null && mounted) {
      SoundEffectService.playAcceptedSound();
      ConfettiCelebration.show(
        context,
        title: '🎉 ¡OFERTA ACEPTADA!',
        subtitle: '¡El cliente aceptó tu oferta para este trabajo!',
        duration: const Duration(milliseconds: 2000),
      );

      // Cerrar modales o bottom sheets que pudiesen estar abiertos en el worker
      try {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      } catch (_) {}

      // Navegar a JobInProgressScreen
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          ConfettiCelebration.dismiss();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => JobInProgressScreen(requestId: requestId),
            ),
          );
        }
      });
    } else if (widget.role == 'client' && myId == clientUserId && mounted) {
      // Notificación sonora para el cliente
      SoundEffectService.playAcceptedSound();
    }
  }

  void _onOfferNew(dynamic payload) {
    if (widget.role != 'client') return;
    SoundEffectService.playCashSound();
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    final amount = map['amount'];
    final bodyText = amount != null
        ? 'Un trabajador ofertó Bs $amount'
        : 'Un trabajador ha enviado una oferta para tu solicitud';
    ToastService.show(
      title: '💰 ¡Nueva oferta recibida!',
      body: bodyText,
      type: ToastType.success,
      duration: const Duration(seconds: 6),
      onTap: () {
        if (!mounted || currentIndex == 0) return;
        setState(() {
          currentIndex = 0;
          _visitedIndices.add(0);
        });
      },
    );
  }

  void _onOfferClientCounter(dynamic payload) {
    if (widget.role != 'worker') return;
    SoundEffectService.playCashSound();
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    final newBudget = map['newBudget'];
    final bodyText = newBudget != null
        ? 'Nuevo presupuesto: Bs $newBudget'
        : 'El cliente mejoró la oferta de su solicitud';
    ToastService.show(
      title: '💰 ¡El cliente mejoró su oferta!',
      body: bodyText,
      type: ToastType.success,
      duration: const Duration(seconds: 6),
      onTap: () {
        if (!mounted || currentIndex == 0) return;
        setState(() {
          currentIndex = 0;
          _visitedIndices.add(0);
        });
      },
    );
  }

  void _onNewRequestAlert() {
    final event = NewRequestAlert.instance.lastEvent.value;
    if (event == null || !mounted) return;

    ToastService.show(
      title: event.title,
      body: event.body,
      type: ToastType.success,
      duration: const Duration(seconds: 6),
      onTap: () {
        if (!mounted || currentIndex == 0) return;
        setState(() {
          currentIndex = 0;
          _visitedIndices.add(0);
        });
      },
    );
  }

  void _onMessageNew(dynamic payload) {
    final myId = SessionStore.currentUser?.id;
    final map = payload is Map ? payload : <dynamic, dynamic>{};
    final senderUserId = map['message']?['senderUserId']?.toString();
    final rawContent = map['message']?['content']?.toString() ?? '';

    // Ignorar mensajes enviados por nosotros o mensajes del sistema (senderUserId null)
    if (senderUserId == null ||
        senderUserId == 'null' ||
        senderUserId == myId) {
      return;
    }

    // 1. Reproducir sonido de notificación háptica
    SoundEffectService.playMessageChime();

    // 2. Incrementar badge de no leídos si no estamos en la pestaña de mensajes
    if (currentIndex != _messagesTabIndex) {
      UnreadMessagesNotifier.instance.increment();
    }

    // 3. Formatear vista previa del mensaje
    String previewText = rawContent.trim();
    if (previewText.startsWith('[Foto]') ||
        previewText.startsWith('[Imagen]') ||
        previewText.contains('/image/upload/') ||
        previewText.endsWith('.jpg') ||
        previewText.endsWith('.png')) {
      previewText = '📷 Te envió una foto';
    } else if (previewText.startsWith('[Audio]') ||
        previewText.startsWith('[Voz]') ||
        previewText.endsWith('.mp3') ||
        previewText.endsWith('.m4a') ||
        previewText.endsWith('.wav')) {
      previewText = '🎤 Te envió un mensaje de voz';
    } else if (previewText.startsWith('[Ubicación]')) {
      previewText = '📍 Te envió una ubicación';
    } else if (previewText.length > 60) {
      previewText = '${previewText.substring(0, 57)}...';
    }

    final senderRoleTitle = widget.role == 'worker'
        ? '💬 Mensaje de tu cliente'
        : '💬 Mensaje de tu trabajador';

    // 4. Mostrar toast in-app si no estamos viendo la pestaña de mensajes
    if (currentIndex != _messagesTabIndex) {
      ToastService.show(
        title: senderRoleTitle,
        body: previewText.isNotEmpty ? previewText : 'Te envió un mensaje',
        type: ToastType.info,
        duration: const Duration(seconds: 5),
        onTap: () {
          if (!mounted) return;
          setState(() {
            currentIndex = _messagesTabIndex;
            _visitedIndices.add(_messagesTabIndex);
          });
        },
      );
    }
  }

  Future<void> _onVerificationUpdated(dynamic payload) async {
    final currentUser = SessionStore.currentUser;
    if (currentUser == null) {
      return;
    }

    final data = payload is Map
        ? Map<String, dynamic>.from(payload)
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
    );

    await SessionStore.setCurrentUser(updatedUser);

    final message = data['message']?.toString().trim().isNotEmpty == true
        ? data['message'].toString().trim()
        : nextVerificationStatus == 'verified'
            ? 'Tu perfil fue verificado correctamente.'
            : 'Tu estado de verificacion fue actualizado.';

    if (!mounted) {
      return;
    }

    final color = nextVerificationStatus == 'verified'
        ? Colors.green.shade600
        : Colors.blueGrey.shade700;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
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
                  UnreadMessagesNotifier.instance.reset();
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
