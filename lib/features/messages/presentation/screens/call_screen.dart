import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:mobile/core/config/app_config.dart';

class CallScreen extends StatelessWidget {
  final String callId;
  final String currentUserId;
  final String currentUserName;

  const CallScreen({
    super.key,
    required this.callId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ZegoUIKitPrebuiltCall(
        appID: AppConfig.zegoAppId,
        appSign: AppConfig.zegoAppSign,
        userID: currentUserId,
        userName: currentUserName,
        callID: callId,
        // Using voice call config by default as requested.
        // Users can still enable camera if they want using the UI.
        config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
          ..turnOnCameraWhenJoining = false,
        events: ZegoUIKitPrebuiltCallEvents(
          // Cierra la pantalla al terminar la llamada (incluye cuando la otra
          // persona cuelga). defaultAction ya vuelve a la pantalla anterior.
          onCallEnd: (event, defaultAction) => defaultAction.call(),
        ),
      ),
    );
  }
}
