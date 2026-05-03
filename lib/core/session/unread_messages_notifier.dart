import 'package:flutter/foundation.dart';

/// Contador global de mensajes no leídos.
/// Se incrementa cuando llega un 'message.new' por socket.
/// Se resetea a 0 cuando el usuario abre la pantalla de mensajes.
class UnreadMessagesNotifier extends ValueNotifier<int> {
  UnreadMessagesNotifier._() : super(0);

  static final UnreadMessagesNotifier instance = UnreadMessagesNotifier._();

  void increment() => value = value + 1;

  void reset() => value = 0;
}
