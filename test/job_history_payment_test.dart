import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/history/presentation/screens/job_history_details_screen.dart';

void main() {
  Future<void> showJob(WidgetTester tester, Map<String, dynamic> job) async {
    await tester.pumpWidget(
        MaterialApp(home: JobHistoryDetailsScreen(job: job, isClient: true)));
    await tester.pump();
  }

  testWidgets('completion and settled amount do not confirm cash payment',
      (tester) async {
    await showJob(tester,
        {'requestStatus': 'completed', 'amount': 110, 'settledAmount': 110});
    expect(find.text('Pagado'), findsNothing);
    expect(find.text('Sin confirmar'), findsOneWidget);
    expect(find.text('Bs 110.00'), findsOneWidget);
  });

  testWidgets('an explicit payment confirmation displays paid', (tester) async {
    await showJob(tester,
        {'requestStatus': 'completed', 'amount': 110, 'paymentStatus': 'paid'});
    expect(find.text('Pagado'), findsOneWidget);
  });
}
