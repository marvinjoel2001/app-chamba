/// Legacy notification context may omit the counterpart/final amount.
/// Only an accepted history entry can identify the contracted worker.
Map<String, dynamic> withAcceptedRequestHistory(
    Map<String, dynamic> context, Iterable<dynamic> history, String requestId) {
  for (final entry in history) {
    if (entry is Map &&
        entry['requestId'] == requestId &&
        entry['offerStatus'] == 'accepted') {
      return {
        ...context,
        ...Map<String, dynamic>.from(entry),
        'requestStatus': context['requestStatus']
      };
    }
  }
  return context;
}
