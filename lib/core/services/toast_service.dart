import 'dart:async';
import 'package:flutter/material.dart';

import '../../app.dart';

enum ToastType { info, success, error }

class ToastService {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void show({
    required String title,
    required String body,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlayState = ChambaApp.navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _removeEntry();
    _timer?.cancel();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: _buildToastWidget(title, body, type),
          ),
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);

    _timer = Timer(duration, () {
      _hide();
    });
  }

  static void _hide() {
    _removeEntry();
    _timer?.cancel();
    _timer = null;
  }

  static void _removeEntry() {
    // remove() lanza si el overlay ya fue desmontado (p. ej. hot restart);
    // no debe tumbar la app por un toast.
    try {
      _overlayEntry?.remove();
    } catch (_) {}
    _overlayEntry = null;
  }

  static Widget _buildToastWidget(String title, String body, ToastType type) {
    Color primaryColor;
    Color bgColor;
    IconData iconData;

    switch (type) {
      case ToastType.error:
        primaryColor = const Color(0xFFD32F2F);
        bgColor = const Color(0xFFFFEBEE);
        iconData = Icons.error_outline;
        break;
      case ToastType.success:
        primaryColor = const Color(0xFF388E3C);
        bgColor = const Color(0xFFE8F5E9);
        iconData = Icons.check_circle_outline;
        break;
      case ToastType.info:
      default:
        primaryColor = const Color(0xFF1976D2);
        bgColor = const Color(0xFFE3F2FD);
        iconData = Icons.info_outline;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _hide,
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(
                Icons.close,
                color: Color(0xFF9E9E9E),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
