import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/messages/data/models/chat_message_model.dart';

void main() {
  test('final work event preserves centavos without claiming a payment', () {
    final message = ChatMessageModel.fromJson({
      'id': 'thread:event:work_completed',
      'threadId': 'thread',
      'senderUserId': 'system',
      'type': 'system',
      'systemEvent': 'work_completed',
      'systemData': {'price': 0.57},
      'createdAt': '2026-10-09T12:00:00Z',
    });
    expect(message.isSystem, isTrue);
    expect(message.displayContent, 'Trabajo completado — Bs 0.57');
    expect(message.toJson()['systemData'], {'price': 0.57});
  });
}
