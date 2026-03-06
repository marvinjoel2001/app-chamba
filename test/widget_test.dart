import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app.dart';

void main() {
  testWidgets('renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ChambaApp()));

    expect(find.text('Chamba'), findsOneWidget);
    expect(find.text('CONNECTING OPPORTUNITIES'), findsOneWidget);
  });
}
