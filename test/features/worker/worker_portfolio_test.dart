import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/offers/domain/entities/offers_payload_entity.dart';
import 'package:mobile/features/offers/domain/repositories/offers_repository.dart';
import 'package:mobile/features/offers/domain/usecases/offers_usecases.dart';
import 'package:mobile/features/offers/presentation/screens/worker_profile_screen.dart';
import 'package:mobile/features/worker/data/repositories/worker_portfolio_repository.dart';
import 'package:mobile/features/worker/domain/entities/worker_portfolio_photo.dart';
import 'package:mobile/features/worker/presentation/screens/worker_portfolio_screen.dart';
import 'package:mobile/features/worker/presentation/widgets/worker_portfolio_gallery.dart';

List<WorkerPortfolioPhoto> photos(int count) => List.generate(
      count,
      (index) => WorkerPortfolioPhoto(
        id: 'photo-$index',
        url: 'https://images.example/$index.jpg',
        caption: 'Trabajo ${index + 1}',
      ),
    );

class _PortfolioRepository implements WorkerPortfolioRepository {
  List<WorkerPortfolioPhoto> items = [];
  bool failLoad = false;
  bool failDelete = false;
  int additions = 0;
  int deletions = 0;
  String? uploaded;

  @override
  Future<List<WorkerPortfolioPhoto>> list() async {
    if (failLoad) throw Exception('No se pudo cargar');
    return List.of(items);
  }

  @override
  Future<WorkerPortfolioPhoto> add({required String imageBase64, required String caption}) async {
    additions++;
    uploaded = imageBase64;
    final item = WorkerPortfolioPhoto(id: 'new', url: 'https://images.example/new.jpg', caption: caption);
    items.insert(0, item);
    return item;
  }

  @override
  Future<void> remove(String photoId) async {
    deletions++;
    if (failDelete) throw Exception('No se pudo eliminar');
    items.removeWhere((photo) => photo.id == photoId);
  }
}

class _OffersRepository implements OffersRepository {
  _OffersRepository(this.items);
  final List<WorkerPortfolioPhoto> items;

  @override
  Future<Result<OffersPayloadEntity>> workerProfile(String workerId) async {
    return Success(OffersPayloadEntity(payload: {
      'worker': {
        'firstName': 'Diego',
        'lastName': 'Perez',
        'portfolio': items.map((photo) => {'id': photo.id, 'url': photo.url, 'caption': photo.caption}).toList(),
      },
      'reviews': [],
    }));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');

  Future<void> open(WidgetTester tester, _PortfolioRepository repository, {bool cancelPicker = false}) async {
    await tester.pumpWidget(MaterialApp(home: WorkerPortfolioScreen(
      repository: repository,
      pickPhoto: (_) async => cancelPicker ? null : XFile.fromData(png, name: 'work.png'),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('empty portfolio and failed load can be retried', (tester) async {
    final repository = _PortfolioRepository()..failLoad = true;
    await open(tester, repository);
    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.text('Agregar foto'), findsNothing);
    repository.failLoad = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 20 fotos'), findsOneWidget);
    expect(find.text('Agregar foto'), findsOneWidget);
  });

  testWidgets('publishes a selected photo with its caption', (tester) async {
    final repository = _PortfolioRepository();
    await open(tester, repository);
    await tester.tap(find.text('Agregar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galer\u00eda'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pintura de fachada');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(repository.additions, 1);
    expect(repository.uploaded, startsWith('data:image/png;base64,'));
    expect(find.text('1 / 20 fotos'), findsOneWidget);
    expect(find.text('Pintura de fachada'), findsOneWidget);
    expect(find.text('Foto publicada'), findsOneWidget);
  });

  testWidgets('canceling the picker does not publish a photo', (tester) async {
    final repository = _PortfolioRepository();
    await open(tester, repository, cancelPicker: true);
    await tester.tap(find.text('Agregar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C\u00e1mara'));
    await tester.pumpAndSettle();
    expect(repository.additions, 0);
    expect(find.text('0 / 20 fotos'), findsOneWidget);
  });

  testWidgets('failed deletion keeps the photo and a successful retry removes it', (tester) async {
    final repository = _PortfolioRepository()..items = photos(1)..failDelete = true;
    await open(tester, repository);
    await tester.tap(find.byTooltip('Eliminar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.deletions, 0);
    await tester.tap(find.byTooltip('Eliminar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Trabajo 1'), findsOneWidget);
    expect(find.text('No se pudo eliminar'), findsOneWidget);
    repository.failDelete = false;
    await tester.tap(find.byTooltip('Eliminar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 20 fotos'), findsOneWidget);
    expect(find.text('Trabajo 1'), findsNothing);
  });

  testWidgets('the limit hides the add control without truncating the gallery', (tester) async {
    final repository = _PortfolioRepository()..items = photos(20);
    await open(tester, repository);
    expect(find.text('Agregar foto'), findsNothing);
    expect(find.text('20 / 20 fotos'), findsOneWidget);
    expect(tester.widget<WorkerPortfolioGallery>(find.byType(WorkerPortfolioGallery)).photos.length, 20);
  });

  testWidgets('client profile shows every photo and never exposes delete controls', (tester) async {
    await tester.pumpWidget(MaterialApp(home: WorkerProfileScreen(
      workerId: 'worker',
      getWorkerProfileUseCase: GetWorkerProfileUseCase(_OffersRepository(photos(6))),
    )));
    await tester.pumpAndSettle();
    expect(tester.widget<WorkerPortfolioGallery>(find.byType(WorkerPortfolioGallery)).photos.length, 6);
    expect(find.byTooltip('Eliminar foto'), findsNothing);
    final fifthPhoto = find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Ver trabajo 5');
    await tester.ensureVisible(fifthPhoto);
    await tester.tap(fifthPhoto);
    await tester.pumpAndSettle();
    expect(find.text('Trabajo 5 de 6'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Trabajo 6 de 6'), findsOneWidget);
  });

  testWidgets('gallery fits a narrow viewport with long captions', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _PortfolioRepository()..items = const [
      WorkerPortfolioPhoto(id: '1', url: 'https://images.example/1.jpg', caption: 'Restauracion de instalaciones y acabados de una fachada completa con pintura'),
    ];
    await open(tester, repository);
    expect(tester.takeException(), isNull);
  });
}
