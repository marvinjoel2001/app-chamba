import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/chamba_widgets.dart';

Widget host(Widget nav,
    {double scale = 1, double bottom = 0, bool reducedMotion = false}) {
  final theme = AppTheme.light();
  return MaterialApp(
    theme: theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'NavigationQAFont'),
    ),
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(scale),
        padding: EdgeInsets.only(bottom: bottom),
        disableAnimations: reducedMotion,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.colorBackground,
        bottomNavigationBar: nav,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final font = ByteData.sublistView(
        await File('docs/notifications-design/fonts/PlusJakartaSans.ttf')
            .readAsBytes());
    for (final family in [
      'NavigationQAFont',
      'PlusJakartaSans_regular',
      'PlusJakartaSans_500',
      'PlusJakartaSans_600',
      'PlusJakartaSans_700',
      'PlusJakartaSans_800',
    ]) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
  });

  for (final role in ['client', 'worker']) {
    testWidgets('$role preserves every tab callback and selection',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final taps = <int>[];
      var selected = 0;
      await tester
          .pumpWidget(host(StatefulBuilder(builder: (context, setState) {
        return ChambaBottomNavWithBadge(
          role: role,
          currentIndex: selected,
          unreadCount: 7,
          messagesTabIndex: role == 'worker' ? 2 : 1,
          onTap: (index) {
            taps.add(index);
            setState(() => selected = index);
          },
        );
      })));
      await tester.pumpAndSettle();
      final labels = role == 'worker'
          ? ['Inicio', 'Billetera', 'Notificaciones', 'Perfil']
          : ['Inicio', 'Notificaciones', 'Perfil'];
      for (var index = 0; index < labels.length; index++) {
        await tester.tap(find.byKey(ValueKey('chamba-nav-tab-$index')));
        await tester.pumpAndSettle();
        expect(taps.last, index);
        expect(
            tester.getSemantics(find.byKey(ValueKey('chamba-nav-tab-$index'))),
            matchesSemantics(
              label: labels[index] == 'Notificaciones'
                  ? 'Notificaciones, 7 sin leer'
                  : labels[index],
              isButton: true,
              isSelected: true,
              hasSelectedState: true,
              hasTapAction: true,
            ));
      }
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('$role uses its wave and Home icon', (tester) async {
      await tester.pumpWidget(
          host(ChambaBottomNav(role: role, currentIndex: 0, onTap: (_) {})));
      await tester.pumpAndSettle();
      final assets = tester.widgetList<Image>(find.byType(Image)).map((widget) {
        final provider = widget.image;
        final asset =
            provider is ResizeImage ? provider.imageProvider : provider;
        return (asset as AssetImage).assetName;
      }).toList();
      expect(
          assets,
          contains(
              'assets/images/navigation/${role == 'worker' ? 'worker' : 'client'}-wave.png'));
      expect(
          assets,
          contains(
              'assets/images/navigation/${role == 'worker' ? 'briefcase' : 'home'}.png'));
      expect(find.text('Billetera'),
          role == 'worker' ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('badge updates, hides zero and caps visible counts at 99+',
      (tester) async {
    for (final count in [1, 12, 123, 0]) {
      await tester.pumpWidget(host(ChambaBottomNavWithBadge(
          role: 'client',
          currentIndex: 1,
          unreadCount: count,
          messagesTabIndex: 1,
          onTap: (_) {})));
      await tester.pumpAndSettle();
      if (count > 0) {
        expect(find.text(count > 99 ? '99+' : '$count'), findsOneWidget);
      } else {
        expect(find.text('0'), findsNothing);
        expect(find.text('99+'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    }
  });

  for (final role in ['client', 'worker']) {
    testWidgets(
        '$role slides to the tapped tab and then stops scheduling frames',
        (tester) async {
      var selected = 0;
      final taps = <int>[];
      await tester
          .pumpWidget(host(StatefulBuilder(builder: (context, setState) {
        return ChambaBottomNavWithBadge(
          role: role,
          currentIndex: selected,
          unreadCount: 12,
          messagesTabIndex: role == 'worker' ? 2 : 1,
          onTap: (index) {
            taps.add(index);
            setState(() => selected = index);
          },
        );
      })));
      await tester.pumpAndSettle();
      final highlight = find.byKey(const ValueKey('chamba-nav-selection'));
      final initialX = tester.getCenter(highlight).dx;
      final destination = role == 'worker' ? 2 : 1;
      final tab = find.byKey(ValueKey('chamba-nav-tab-$destination'));
      final targetX = tester.getCenter(tab).dx;
      await tester.tap(tab);
      // Navigation changes synchronously, without waiting for the animation.
      expect(taps, [destination]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getCenter(highlight).dx, greaterThan(initialX));
      expect(tester.getCenter(highlight).dx, lessThan(targetX));
      expect(find.text('12'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.getCenter(highlight).dx, closeTo(targetX, 0.01));
      // The native InkWell press ripple may outlast the 260 ms selector.
      final frames =
          await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(frames, lessThan(60));
      expect(tester.getCenter(highlight).dx, closeTo(targetX, 0.01));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(taps, [destination]);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'rapid taps and a live badge update finish on the last selected tab',
      (tester) async {
    var selected = 0;
    var count = 1;
    late StateSetter update;
    final taps = <int>[];
    await tester.pumpWidget(host(StatefulBuilder(builder: (context, setState) {
      update = setState;
      return ChambaBottomNavWithBadge(
        role: 'worker',
        currentIndex: selected,
        unreadCount: count,
        messagesTabIndex: 2,
        onTap: (index) {
          taps.add(index);
          setState(() => selected = index);
        },
      );
    })));
    await tester.pumpAndSettle();
    for (final index in [1, 3, 0, 2]) {
      await tester.tap(find.byKey(ValueKey('chamba-nav-tab-$index')));
      await tester.pump(const Duration(milliseconds: 30));
    }
    update(() => count = 8);
    await tester.pump();
    expect(find.text('8'), findsOneWidget);
    expect(taps, [1, 3, 0, 2]);
    await tester.pumpAndSettle();
    expect(
        tester.getCenter(find.byKey(const ValueKey('chamba-nav-selection'))).dx,
        closeTo(
            tester.getCenter(find.byKey(const ValueKey('chamba-nav-tab-2'))).dx,
            0.01));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion changes the selection immediately',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(host(StatefulBuilder(builder: (context, setState) {
      return ChambaBottomNav(
          role: 'client',
          currentIndex: selected,
          onTap: (index) => setState(() => selected = index));
    }), reducedMotion: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chamba-nav-tab-2')));
    await tester.pump();
    final highlight = find.byKey(const ValueKey('chamba-nav-selection'));
    expect(
        tester.widget<AnimatedPositioned>(highlight).duration, Duration.zero);
    expect(
        tester.getCenter(highlight).dx,
        closeTo(
            tester.getCenter(find.byKey(const ValueKey('chamba-nav-tab-2'))).dx,
            0.01));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'narrow screen, large text and bottom safe area keep tabs tappable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final taps = <int>[];
    await tester.pumpWidget(host(
        ChambaBottomNavWithBadge(
            role: 'worker',
            currentIndex: 2,
            unreadCount: 123,
            messagesTabIndex: 2,
            onTap: taps.add),
        scale: 2,
        bottom: 24));
    await tester.pumpAndSettle();
    for (var index = 0; index < 4; index++) {
      final tab = find.byKey(ValueKey('chamba-nav-tab-$index'));
      expect(tester.getSize(tab).width, greaterThanOrEqualTo(48));
      expect(tester.getRect(tab).bottom, lessThanOrEqualTo(616));
      await tester.tap(tab);
    }
    expect(taps, [0, 1, 2, 3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture native reference states and badges for visual QA',
      (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(390, 180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final state in [
      (name: 'client', role: 'client', index: 0, count: 0),
      (name: 'worker', role: 'worker', index: 0, count: 0),
      (name: 'worker-wallet', role: 'worker', index: 1, count: 12),
      (name: 'client-notifications', role: 'client', index: 1, count: 123),
    ]) {
      final capture = GlobalKey();
      await tester.pumpWidget(host(RepaintBoundary(
          key: capture,
          child: ColoredBox(
            color: AppTheme.colorBackground,
            child: ChambaBottomNavWithBadge(
              role: state.role,
              currentIndex: state.index,
              unreadCount: state.count,
              messagesTabIndex: state.role == 'worker' ? 2 : 1,
              onTap: (_) {},
            ),
          ))));
      // Decode the exact resized providers used by the live component.
      final imageWidgets =
          tester.widgetList<Image>(find.byType(Image)).toList();
      await tester.runAsync(() async {
        final context = tester.element(find.byKey(capture));
        for (final image in imageWidgets) {
          await precacheImage(image.image, context);
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final picture = await boundary.toImage(pixelRatio: 3);
        final data = await picture.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/bottom-nav-design/${state.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        picture.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    debugDisableShadows = true;
  });

  testWidgets('capture the real selection transition for both roles',
      (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(390, 180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final role in ['client', 'worker']) {
      var selected = 0;
      late StateSetter update;
      final capture = GlobalKey();
      await tester
          .pumpWidget(host(StatefulBuilder(builder: (context, setState) {
        update = setState;
        return RepaintBoundary(
          key: capture,
          child: ColoredBox(
            color: AppTheme.colorBackground,
            child: ChambaBottomNavWithBadge(
              role: role,
              currentIndex: selected,
              unreadCount: 3,
              messagesTabIndex: role == 'worker' ? 2 : 1,
              onTap: (index) => setState(() => selected = index),
            ),
          ),
        );
      })));
      final imageWidgets =
          tester.widgetList<Image>(find.byType(Image)).toList();
      await tester.runAsync(() async {
        for (final image in imageWidgets) {
          await precacheImage(image.image, tester.element(find.byKey(capture)));
        }
      });
      await tester.pumpAndSettle();
      update(() => selected = role == 'worker' ? 2 : 1);
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        if (frame > 0) await tester.pump(const Duration(milliseconds: 40));
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          final picture = await boundary.toImage(pixelRatio: 2);
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          final file = File('docs/bottom-nav-design/motion/$role-$frame.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    }
    debugDisableShadows = true;
  });
}
