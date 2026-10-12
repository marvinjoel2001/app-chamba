import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/notifications/domain/models/app_notification.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_screen.dart';

AppNotification notice(String id, String type,
        {bool read = false, String? title, Map<String, dynamic>? data}) =>
    AppNotification(
        id: id,
        title: title ?? id,
        body: 'Información del trabajo para revisar.',
        type: type,
        isRead: read,
        createdAt: DateTime(2026, 10, 11, 18, 22),
        data: data);
Widget screen(NotificationsScreen child,
    {double scale = 1, GlobalKey? capture}) {
  final base = AppTheme.light();
  final theme = base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'NotificationQAFont'),
    primaryTextTheme:
        base.primaryTextTheme.apply(fontFamily: 'NotificationQAFont'),
    appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: base.appBarTheme.titleTextStyle
            ?.copyWith(fontFamily: 'NotificationQAFont')),
  );
  return MaterialApp(
      theme: theme,
      home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: capture, child: child)));
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final font = ByteData.sublistView(
        await File('docs/notifications-design/fonts/PlusJakartaSans.ttf')
            .readAsBytes());
    for (final family in [
      'NotificationQAFont',
      'PlusJakartaSans',
      'Roboto',
      'PlusJakartaSans_regular',
      'PlusJakartaSans_500',
      'PlusJakartaSans_600',
      'PlusJakartaSans_700',
      'PlusJakartaSans_800'
    ]) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets(
      'filters jobs, messages and system while excluding payment notices',
      (tester) async {
    await tester.pumpWidget(screen(NotificationsScreen(previewItems: [
      notice('oferta', 'offer_new'),
      notice('pago', 'payment_received'),
      notice('chat', 'message_new'),
      notice('sistema', 'verification_update')
    ])));
    await tester.pumpAndSettle();
    expect(find.text('pago'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Pagos'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Trabajos'));
    await tester.pumpAndSettle();
    expect(find.text('oferta'), findsOneWidget);
    expect(find.text('chat'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mensajes'));
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
    expect(find.text('oferta'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Todas'));
    await tester.pumpAndSettle();
    expect(find.text('oferta'), findsOneWidget);
    expect(find.text('pago'), findsNothing);
  });
  testWidgets(
      'action opens the original payload and marks only the tapped notice',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final marked = <String>[];
    AppNotification? opened;
    await tester.pumpWidget(screen(NotificationsScreen(
        previewItems: [
          notice('Oferta', 'offer_new', data: {'requestId': 'real-request'})
        ],
        markRead: (ids) async => marked.addAll(ids),
        onOpenNotification: (n) {
          opened = n;
          return true;
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver ofertas'));
    await tester.pumpAndSettle();
    expect(opened?.data?['requestId'], 'real-request');
    expect(marked, ['Oferta']);
    expect(find.bySemanticsLabel('Sin leer'), findsNothing);
    semantics.dispose();
  });

  testWidgets('quick taps keep both notices queued for marking as read',
      (tester) async {
    final first = Completer<void>();
    final batches = <List<String>>[];
    await tester.pumpWidget(screen(NotificationsScreen(
        previewItems: [
          notice('Uno', 'announcement'),
          notice('Dos', 'announcement')
        ],
        markRead: (ids) {
          batches.add(ids);
          return batches.length == 1 ? first.future : Future.value();
        },
        onOpenNotification: (_) => true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver detalle').first);
    await tester.pump();
    await tester.tap(find.text('Ver detalle').last);
    await tester.pump();
    first.complete();
    await tester.pumpAndSettle();
    expect(batches, [
      ['Uno'],
      ['Dos']
    ]);
  });
  testWidgets('options mark only the visible category as read', (tester) async {
    final marked = <String>[];
    await tester.pumpWidget(screen(NotificationsScreen(previewItems: [
      notice('Trabajo', 'request_new'),
      notice('Mensaje', 'message_new')
    ], markRead: (ids) async => marked.addAll(ids))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mensajes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opciones de notificaciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar visibles como leídas'));
    await tester.pumpAndSettle();
    expect(marked, ['Mensaje']);
  });
  testWidgets(
      'unsupported notice opens readable detail rather than a duplicate center',
      (tester) async {
    await tester.pumpWidget(screen(NotificationsScreen(
        previewItems: [notice('Aviso completo', 'announcement')])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar'), findsNothing);
  });
  testWidgets('failed mark-read leaves the unread notice and offers an error',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(screen(NotificationsScreen(
        previewItems: [notice('Aviso', 'announcement')],
        markRead: (_) async => throw Exception('offline'),
        onOpenNotification: (_) => true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Sin leer')), findsOneWidget);
    expect(find.textContaining('No pudimos marcar'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('initial connection error can be retried', (tester) async {
    var calls = 0;
    await tester.pumpWidget(screen(NotificationsScreen(loadPage: (_) async {
      if (calls++ == 0) throw Exception('offline');
      return (items: [notice('Recuperado', 'announcement')], hasMore: false);
    })));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Recuperado'), findsOneWidget);
  });
  testWidgets(
      'an empty category can load the next page and deduplicates notices',
      (tester) async {
    final pages = <int>[];
    await tester.pumpWidget(screen(NotificationsScreen(loadPage: (page) async {
      pages.add(page);
      return page == 1
          ? (items: [notice('Trabajo', 'request_new')], hasMore: true)
          : (
              items: [
                notice('Trabajo', 'request_new'),
                notice('Mensaje nuevo', 'message_new')
              ],
              hasMore: false
            );
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mensajes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cargar más avisos'));
    await tester.tap(find.text('Cargar más avisos'));
    await tester.pumpAndSettle();
    expect(find.text('Mensaje nuevo'), findsOneWidget);
    expect(pages, [1, 2]);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Trabajos'));
    await tester.pumpAndSettle();
    expect(find.text('Trabajo'), findsOneWidget);
  });
  testWidgets(
      'large text keeps buttons reachable without overflowing illustrations',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen(
        NotificationsScreen(previewItems: [
          notice('Título largo de un trabajo completado correctamente',
              'job_finished',
              data: {'requestId': 'job'})
        ]),
        scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Ver resumen'));
    expect(find.text('Ver resumen'), findsOneWidget);
  });
  testWidgets(
      'renders the reference state for visual QA with generated artwork',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final date = DateTime.now().subtract(const Duration(days: 1));
    AppNotification sample(String id, String title, String body, String type,
            int h, int m, Map<String, dynamic> data) =>
        AppNotification(
            id: id,
            title: title,
            body: body,
            type: type,
            isRead: true,
            createdAt: DateTime(date.year, date.month, date.day, h, m),
            data: data);
    await tester.pumpWidget(screen(
        NotificationsScreen(previewItems: [
          sample('1', 'Jorge ha llegado', 'El trabajador llegó a tu ubicación.',
              'worker_arrived', 23, 6, {'requestId': 'job'}),
          sample(
              '2',
              'Jorge ofertó Bs 100',
              'En tu solicitud: limpieza de tu hogar.',
              'offer_new',
              21,
              18,
              {'requestId': 'offer'}),
          sample(
              '3',
              'Trabajo finalizado',
              'Jorge completó el trabajo correctamente.',
              'job_finished',
              19,
              40,
              {'requestId': 'completed'}),
          sample('4', 'Nuevo mensaje', 'Jorge envió un nuevo mensaje.',
              'message_new', 18, 22, {'threadId': 'chat'}),
        ]),
        capture: key));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      for (final asset in ['location', 'coins', 'completed', 'messages']) {
        await precacheImage(
            ResizeImage(AssetImage('assets/images/notifications/$asset.png'),
                width: 252),
            key.currentContext!);
      }
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('docs/notifications-design').create(recursive: true);
      await File('docs/notifications-design/implementation.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
  testWidgets(
      'worker sees clear request, accepted-work, proposal and message cards',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SessionStore.currentUser = const SessionUser(
        id: 'qa-worker',
        type: 'worker',
        firstName: 'Jorge',
        email: 'qa@example.test');
    addTearDown(() => SessionStore.currentUser = null);
    final key = GlobalKey();
    final opened = <String>[];
    await tester.pumpWidget(screen(
        NotificationsScreen(
            previewItems: [
              AppNotification(
                  id: 'request',
                  title: 'Trabajo nuevo cerca: Limpieza',
                  body:
                      'Una solicitud de Bs 150 a 1,2 km. Revisa si te conviene.',
                  type: 'request_new',
                  isRead: false,
                  createdAt: DateTime.now(),
                  data: {'requestId': 'new-work'}),
              AppNotification(
                  id: 'accepted',
                  title: '¡Tu oferta fue aceptada!',
                  body: 'Ana aceptó tu oferta para limpiar su hogar.',
                  type: 'offer_accepted',
                  isRead: false,
                  createdAt: DateTime.now(),
                  data: {'requestId': 'accepted-work'}),
              AppNotification(
                  id: 'proposal',
                  title: 'Ana mejoró su propuesta',
                  body: 'Nuevo presupuesto: Bs 180 para su solicitud.',
                  type: 'counter_offer',
                  isRead: true,
                  createdAt: DateTime.now(),
                  data: {'requestId': 'proposal-work'}),
              AppNotification(
                  id: 'chat',
                  title: 'Nuevo mensaje de Ana',
                  body: 'Ana envió un mensaje sobre el trabajo.',
                  type: 'message_new',
                  isRead: true,
                  createdAt: DateTime.now(),
                  data: {'threadId': 'thread'}),
            ],
            onOpenNotification: (n) {
              opened.add(n.id);
              return true;
            }),
        capture: key));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final asset in ['completed', 'coins', 'messages']) {
        await precacheImage(
            ResizeImage(AssetImage('assets/images/notifications/$asset.png'),
                width: 252),
            key.currentContext!);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('docs/notifications-design/worker.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('Ver solicitud'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver trabajo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver propuesta'));
    await tester.pumpAndSettle();
    expect(opened, ['request', 'accepted', 'proposal']);
  });
  for (final role in ['client', 'worker']) {
    testWidgets('all four filters select their own notices for $role',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SessionStore.currentUser = SessionUser(
          id: 'filter-user',
          type: role,
          firstName: 'QA',
          email: 'qa@example.test');
      addTearDown(() => SessionStore.currentUser = null);
      final notices = [
        notice('Trabajo ejemplo', 'request_new'),
        notice('Oferta ejemplo', 'offer_new'),
        notice('Pago ejemplo', 'payment_received'),
        notice('Mensaje ejemplo', 'message_new'),
        notice('Soporte ejemplo', 'support_message'),
        notice('Verificación ejemplo', 'verification_update'),
        notice('Aviso general', 'broadcast')
      ];
      await tester
          .pumpWidget(screen(NotificationsScreen(previewItems: notices)));
      await tester.pumpAndSettle();
      final expected = <String, List<String>>{
        'Trabajos': ['Trabajo ejemplo', 'Oferta ejemplo'],
        'Mensajes': ['Mensaje ejemplo', 'Soporte ejemplo'],
        'Sistema': ['Verificación ejemplo', 'Aviso general'],
        'Todas': notices
            .where((n) => n.type != 'payment_received')
            .map((n) => n.title)
            .toList()
      };
      for (final entry in expected.entries) {
        final chip = find.widgetWithText(ChoiceChip, entry.key);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
        for (final title in entry.value) {
          await tester.scrollUntilVisible(find.text(title), 150,
              scrollable: find.byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down));
          expect(find.text(title), findsOneWidget);
        }
        for (final item in notices) {
          if (!entry.value.contains(item.title)) {
            expect(find.text(item.title), findsNothing);
          }
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets(
      'message, profile and support buttons retain their original payload',
      (tester) async {
    final cases = <({String type, String label, Map<String, dynamic> data})>[
      (
        type: 'message_new',
        label: 'Ver mensaje',
        data: {'threadId': 'chat-123'}
      ),
      (
        type: 'verification_update',
        label: 'Ver perfil',
        data: {'deep_link': '/profile'}
      ),
      (
        type: 'support_message',
        label: 'Ver soporte',
        data: {'disputeId': 'support-123'}
      ),
    ];
    for (final entry in cases) {
      AppNotification? opened;
      await tester.pumpWidget(screen(NotificationsScreen(
          key: ValueKey(entry.type),
          previewItems: [notice(entry.type, entry.type, data: entry.data)],
          onOpenNotification: (n) {
            opened = n;
            return true;
          })));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.label));
      await tester.pumpAndSettle();
      expect(opened?.type, entry.type);
      expect(opened?.data, entry.data);
    }
  });
  testWidgets(
      'refresh option fetches new notices while retaining the selected filter',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(screen(NotificationsScreen(loadPage: (_) async {
      calls++;
      return (
        items: [
          notice(calls == 1 ? 'Mensaje anterior' : 'Mensaje actualizado',
              'message_new'),
          notice('Trabajo', 'request_new')
        ],
        hasMore: false
      );
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mensajes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opciones de notificaciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Mensaje actualizado'), findsOneWidget);
    expect(find.text('Mensaje anterior'), findsNothing);
    expect(find.text('Trabajo'), findsNothing);
  });
  testWidgets('empty message filter can return to jobs without losing notices',
      (tester) async {
    await tester.pumpWidget(screen(
        NotificationsScreen(previewItems: [notice('Oferta', 'offer_new')])));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mensajes'));
    await tester.pumpAndSettle();
    expect(find.text('Sin avisos de mensajes'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Trabajos'));
    await tester.pumpAndSettle();
    expect(find.text('Oferta'), findsOneWidget);
  });
  testWidgets(
      'failed pagination can retry the same page and keep previously loaded notices',
      (tester) async {
    final pages = <int>[];
    var failures = 0;
    await tester.pumpWidget(screen(NotificationsScreen(loadPage: (page) async {
      pages.add(page);
      if (page == 1)
        return (items: [notice('Primero', 'broadcast')], hasMore: true);
      if (failures++ == 0) throw Exception('offline');
      return (items: [notice('Segundo', 'broadcast')], hasMore: false);
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cargar más avisos'));
    await tester.pumpAndSettle();
    expect(find.text('Primero'), findsOneWidget);
    await tester.tap(find.text('No pudimos cargar más avisos.'));
    await tester.pumpAndSettle();
    expect(pages, [1, 2, 2]);
    expect(find.text('Primero'), findsOneWidget);
    expect(find.text('Segundo'), findsOneWidget);
  });
  testWidgets(
      'new and read filters update counters only after a successful read',
      (tester) async {
    await tester.pumpWidget(screen(NotificationsScreen(previewItems: [
      notice('Nuevo', 'announcement'),
      notice('Anterior', 'announcement', read: true)
    ], onOpenNotification: (_) => true)));
    await tester.pumpAndSettle();
    expect(find.text('Nuevas 1'), findsOneWidget);
    expect(find.text('Leídas 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Nuevas 1'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('Anterior'), findsNothing);
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevas 0'), findsOneWidget);
    expect(find.text('Leídas 2'), findsOneWidget);
    expect(find.text('No tienes avisos nuevos'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Leídas 2'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('Anterior'), findsOneWidget);
  });
  testWidgets('failed read preserves the new count and state', (tester) async {
    await tester.pumpWidget(screen(NotificationsScreen(
        previewItems: [notice('Nuevo', 'announcement')],
        markRead: (_) async => throw Exception('offline'),
        onOpenNotification: (_) => true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevas 1'), findsOneWidget);
    expect(find.text('Leídas 0'), findsOneWidget);
    expect(find.text('Nueva'), findsOneWidget);
  });
  testWidgets(
      'server counts include unloaded pages and follow the selected category',
      (tester) async {
    await tester.pumpWidget(screen(NotificationsScreen(
        loadPage: (_) async =>
            (items: [notice('Trabajo', 'offer_new')], hasMore: true),
        loadCounts: () async => {
              'offer_new': (unread: 12, read: 7),
              'message_new': (unread: 3, read: 2),
              'payment_received': (unread: 100, read: 100)
            })));
    await tester.pumpAndSettle();
    expect(find.text('Nuevas 15'), findsOneWidget);
    expect(find.text('Leídas 9'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Trabajos'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevas 12'), findsOneWidget);
    expect(find.text('Leídas 7'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mensajes'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevas 3'), findsOneWidget);
    expect(find.text('Leídas 2'), findsOneWidget);
  });
  testWidgets('payment notices do not enter counts or list for either role',
      (tester) async {
    for (final role in ['client', 'worker']) {
      SessionStore.currentUser = SessionUser(
          id: 'qa', type: role, firstName: 'QA', email: 'qa@example.test');
      await tester.pumpWidget(
          screen(NotificationsScreen(key: ValueKey(role), previewItems: [
        notice('Pago', 'payment'),
        notice('Cobro', 'payment_received'),
        notice('Oferta', 'offer_new')
      ])));
      await tester.pumpAndSettle();
      expect(find.text('Pago'), findsNothing);
      expect(find.text('Cobro'), findsNothing);
      expect(find.text('Nuevas 1'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Pagos'), findsNothing);
    }
    SessionStore.currentUser = null;
  });
  testWidgets(
      'marking more than a hundred notices uses batches and preserves counters',
      (tester) async {
    final batches = <List<String>>[];
    await tester.pumpWidget(screen(NotificationsScreen(
        previewItems:
            List.generate(110, (i) => notice('Aviso $i', 'broadcast')),
        markRead: (ids) async => batches.add(ids))));
    await tester.pumpAndSettle();
    expect(find.text('Nuevas 110'), findsOneWidget);
    await tester.tap(find.byTooltip('Opciones de notificaciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar visibles como leídas'));
    await tester.pumpAndSettle();
    expect(batches.map((batch) => batch.length).toList(), [100, 10]);
    expect(find.text('Nuevas 0'), findsOneWidget);
    expect(find.text('Leídas 110'), findsOneWidget);
  });
  testWidgets(
      'a failed summary request clearly labels the available local counts',
      (tester) async {
    await tester.pumpWidget(screen(NotificationsScreen(
        loadPage: (_) async =>
            (items: [notice('Nuevo', 'broadcast')], hasMore: true),
        loadCounts: () async => throw Exception('offline'))));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('Nuevas 1'), findsOneWidget);
    expect(find.text('Conteo de los avisos cargados.'), findsOneWidget);
  });
  testWidgets(
      'reading the loaded new notice does not imply no new notices on later pages',
      (tester) async {
    var remaining = 25;
    await tester.pumpWidget(screen(NotificationsScreen(
        loadPage: (_) async =>
            (items: [notice('Nuevo', 'broadcast')], hasMore: true),
        loadCounts: () async => {'broadcast': (unread: remaining, read: 0)},
        markRead: (_) async {
          remaining--;
        },
        onOpenNotification: (_) => true)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Nuevas 25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevas 24'), findsOneWidget);
    expect(find.text('Hay más avisos para revisar'), findsOneWidget);
    expect(find.text('No tienes avisos nuevos'), findsNothing);
    expect(find.text('Cargar más avisos'), findsOneWidget);
  });
}
