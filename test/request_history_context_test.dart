import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/request/domain/entities/request_history_context.dart';

void main() {
  final context = <String, dynamic>{
    'requestStatus': 'cancelled',
    'amount': 100,
    'budget': 100,
    'worker': null
  };
  test(
      'a rejected or declined offer never becomes the contracted worker in cancellation details',
      () {
    final result = withAcceptedRequestHistory(
        context,
        [
          {
            'requestId': 'job',
            'offerStatus': 'rejected',
            'amount': 110,
            'worker': {'id': 'loser'}
          },
          {
            'requestId': 'job',
            'offerStatus': 'declined',
            'amount': 120,
            'worker': {'id': 'withdrawn'}
          },
        ],
        'job');
    expect(result['worker'], isNull);
    expect(result['amount'], 100);
  });
  test(
      'fallback selects the accepted offer and preserves the authoritative current state',
      () {
    final result = withAcceptedRequestHistory(
        context,
        [
          {
            'requestId': 'job',
            'offerStatus': 'rejected',
            'amount': 110,
            'worker': {'id': 'loser'}
          },
          {
            'requestId': 'job',
            'offerStatus': 'accepted',
            'amount': 120,
            'requestStatus': 'assigned',
            'worker': {'id': 'winner'}
          },
        ],
        'job');
    expect((result['worker'] as Map)['id'], 'winner');
    expect(result['amount'], 120);
    expect(result['requestStatus'], 'cancelled');
    expect(result['budget'], 100);
  });
}
