import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/messages/domain/job_chat_policy.dart';
import 'package:mobile/features/messages/data/models/chat_thread_model.dart';
import 'package:mobile/features/messages/domain/entities/chat_thread.dart';

void main() {
  test('blocks contact and external payment patterns, including obfuscation',
      () {
    for (final text in [
      '+591 7217-7549',
      '7 2 1 7 7 5 4 9',
      '７２１７７５４９',
      '٧٢١٧٧٥٤٩',
      'siete dos uno siete siete cinco cuatro nueve',
      'hola@example.com',
      'hola arroba example punto com',
      'https://example.shop',
      'example.shop',
      'wa.me/59172177549',
      't.me/micuenta',
      '@miusuario',
      'Escríbeme por WhatsApp',
      'w h a t s a p p',
      'mi Instagram',
      'facebook.com/persona',
      'wsp',
      'Págame por PayPal',
      'Mi cuenta bancaria',
      'Transferencia a mi cuenta',
      'Mi IBAN es ES00',
      'QR de pago',
      'Te paso mi celular',
      'Telegram',
      'wha\u200btsapp',
      'Te cobro fuera de Chamba',
    ]) {
      expect(JobChatPolicy.containsExternalContact(text), isTrue, reason: text);
    }
  });
  test('allows coordination, times, addresses and amounts', () {
    for (final text in [
      ...JobChatPolicy.quickReplies,
      'Ingreso por la puerta azul',
      'Calle 12, edificio 45, piso 3',
      'Nos vemos a las 17:30',
      'El precio acordado es Bs 150',
      'Traeré dos herramientas',
      'El pago del trabajo está pendiente'
    ]) {
      expect(JobChatPolicy.containsExternalContact(text), isFalse,
          reason: text);
    }
  });
  Map<String, dynamic> payload(String status, {bool? enabled = true}) => {
        'id': 'thread',
        'requestId': 'job',
        'chatEnabled': enabled,
        'request': {'id': 'job', 'status': status, 'title': 'Plomería'},
      };
  test('unknown and pre-acceptance states fail closed', () {
    for (final status in [
      'searching',
      'negotiating',
      'pending',
      'unknown',
      ''
    ]) {
      final thread = ChatThreadModel.fromJson(payload(status));
      expect(thread.chatEnabled, isFalse);
      expect(thread.canSend, isFalse);
      expect(thread.jobStatus, ChatThreadStatus.pending);
    }
    expect(ChatThreadModel.fromJson(payload('assigned', enabled: null)).canSend,
        isFalse);
  });
  test(
      'assigned work opens the composer and terminal work preserves read-only history',
      () {
    expect(ChatThreadModel.fromJson(payload('assigned')).canSend, isTrue);
    for (final status in ['completed', 'cancelled']) {
      final thread = ChatThreadModel.fromJson(payload(status));
      expect(thread.chatEnabled, isTrue);
      expect(thread.canSend, isFalse);
      expect(thread.isArchived, isTrue);
      expect(ChatThreadModel.fromJson(thread.toJson()).canSend, isFalse);
    }
  });
}
