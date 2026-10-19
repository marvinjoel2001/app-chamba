import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/session/session_credentials.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/worker/presentation/screens/profile_menu_screen.dart';

void main() {
  testWidgets('an already open profile changes from pending to verified',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final allowFetching = GoogleFonts.config.allowRuntimeFetching;
    addTearDown(() {
      GoogleFonts.config.allowRuntimeFetching = allowFetching;
      SessionStore.currentUser = null;
      SessionCredentials.accessToken = null;
    });
    GoogleFonts.config.allowRuntimeFetching = false;
    SessionCredentials.accessToken = null;
    const worker = SessionUser(
        id: 'worker',
        type: 'worker',
        firstName: 'Ana',
        email: 'ana@example.test',
        verificationStatus: 'pending');
    SessionStore.currentUser = worker;
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ProfileMenuScreen())));
    await tester.pump();
    expect(find.text('Verificación en proceso'), findsOneWidget);

    await SessionStore.setCurrentUser(worker.copyWith(
        verificationStatus: 'verified',
        idPhotoVerified: true,
        facePhotoVerified: true));
    await tester.pump();
    expect(find.text('Verificación en proceso'), findsNothing);
    expect(find.text('Verificado'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    SessionStore.currentUser = null;
  });
}
