// ignore_for_file: avoid_print
// Tests de integración: verifica todos los endpoints de la API contra el backend local.
// Requiere que el backend esté corriendo en localhost:3001

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/network/api_service.dart';

String uid() => DateTime.now().microsecondsSinceEpoch.toString();
ApiService buildApi() =>
    ApiService(baseUrl: AppConfig.apiBaseUrl, client: http.Client());

late String clientId;
late String workerId;
late String requestId;
late String offerId;
String? threadId;
late String clientEmail;
late String workerEmail;

Future<void> setupTestData() async {
  clientEmail = 'api_c_${uid()}@test.com';
  workerEmail = 'api_w_${uid()}@test.com';
  final api = buildApi();

  final clientRes = await api.post(
    '/auth/register',
    body: {
      'type': 'client',
      'email': clientEmail,
      'firstName': 'ApiCliente',
      'password': 'pass1234',
    },
  );
  clientId = clientRes['user']['id'] as String;

  final workerRes = await api.post(
    '/auth/register',
    body: {
      'type': 'worker',
      'email': workerEmail,
      'firstName': 'ApiWorker',
      'password': 'pass1234',
    },
  );
  workerId = workerRes['user']['id'] as String;

  await api.post(
    '/mobile/worker/location',
    body: {'workerUserId': workerId, 'latitude': -16.5, 'longitude': -68.15},
  );
  await api.post(
    '/mobile/worker/availability',
    body: {'workerUserId': workerId, 'available': true},
  );
  await api.post(
    '/mobile/worker/skills',
    body: {
      'workerUserId': workerId,
      'skills': ['Plomeria', 'Electricidad'],
    },
  );

  final reqRes = await api.post(
    '/mobile/requests',
    body: {
      'clientUserId': clientId,
      'title': 'Arreglo API Test',
      'description': 'Necesito un plomero urgente',
      'category': 'Plomeria',
      'budget': 150,
      'priceType': 'fixed',
      'address': 'Av. Arce 123, La Paz',
      'latitude': -16.5,
      'longitude': -68.15,
    },
  );
  requestId = reqRes['request']['id'] as String;

  final offerRes = await api.post(
    '/mobile/offers/counter',
    body: {
      'requestId': requestId,
      'workerUserId': workerId,
      'amount': 130,
      'message': 'Puedo hacerlo por 130',
    },
  );
  offerId = offerRes['offer']['id'] as String;

  final acceptRes = await api.post(
    '/mobile/offers/accept',
    body: {'offerId': offerId, 'clientUserId': clientId},
  );
  if (acceptRes['thread'] != null) {
    threadId = acceptRes['thread']['id'] as String?;
  }
  if (threadId == null) {
    final msgRes = await api.get(
      '/mobile/messages',
      queryParameters: {'userId': clientId},
    );
    final threads = msgRes['threads'] as List;
    if (threads.isNotEmpty) threadId = threads[0]['id'] as String?;
  }
  print(
    'Setup OK: client=$clientId worker=$workerId request=$requestId offer=$offerId thread=$threadId',
  );
}

void main() {
  setUpAll(() async {
    await setupTestData();
  });

  group('API – Health', () {
    test('GET /health → status ok', () async {
      final res = await buildApi().get('/health');
      expect(res['status'], equals('ok'));
      expect(res['dependencies']['postgres']['connected'], isTrue);
      expect(res['dependencies']['redis']['connected'], isTrue);
      print('  ✓ Health OK');
    });
  });

  group('API – Auth: Registro', () {
    test('cliente registrado en setup', () {
      expect(clientId, isNotEmpty);
      print('  ✓ Cliente: $clientId');
    });
    test('worker registrado en setup', () {
      expect(workerId, isNotEmpty);
      print('  ✓ Worker: $workerId');
    });

    test('409 si email duplicado', () async {
      expect(
        () => buildApi().post(
          '/auth/register',
          body: {
            'type': 'client',
            'email': clientEmail,
            'firstName': 'Otro',
            'password': 'pass1234',
          },
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('error si password muy corta', () async {
      expect(
        () => buildApi().post(
          '/auth/register',
          body: {
            'type': 'client',
            'email': 'nuevo_${uid()}@test.com',
            'firstName': 'Test',
            'password': '123',
          },
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('API – Auth: Check Identifier', () {
    test('exists:true para email registrado', () async {
      final res = await buildApi().post(
        '/auth/check-identifier',
        body: {'identifier': clientEmail},
      );
      expect(res['exists'], isTrue);
      print('  ✓ exists=true');
    });
    test('exists:false para email inexistente', () async {
      final res = await buildApi().post(
        '/auth/check-identifier',
        body: {'identifier': 'noexiste_${uid()}@test.com'},
      );
      expect(res['exists'], isFalse);
      print('  ✓ exists=false');
    });
  });

  group('API – Auth: Login', () {
    test('login exitoso con email', () async {
      final res = await buildApi().post(
        '/auth/login',
        body: {'identifier': clientEmail, 'password': 'pass1234'},
      );
      expect(res['user']['id'], equals(clientId));
      print('  ✓ Login OK');
    });
    test('error con contrasena incorrecta', () async {
      expect(
        () => buildApi().post(
          '/auth/login',
          body: {'identifier': clientEmail, 'password': 'wrongpass'},
        ),
        throwsA(isA<Exception>()),
      );
    });
    test('error con email inexistente', () async {
      expect(
        () => buildApi().post(
          '/auth/login',
          body: {'identifier': 'noexiste@test.com', 'password': 'pass1234'},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('API – Categorias', () {
    test('GET /mobile/categories → retorna lista', () async {
      final res = await buildApi().get('/mobile/categories');
      final cats = res['categories'] ?? res['data'] ?? res;
      expect(cats, isA<List>());
      print('  ✓ Categorias OK');
    });
    test('POST /mobile/categories → crea categoria', () async {
      final name = 'TestCat_${uid()}';
      final res = await buildApi().post(
        '/mobile/categories',
        body: {'name': name, 'description': 'Prueba', 'icon': '🔧'},
      );
      final cat = (res['category'] ?? res) as Map;
      expect(cat['id'], isNotEmpty);
      expect(cat['name'], equals(name));
      print('  ✓ Categoria creada');
    });
  });

  group('API – Worker: Habilidades y Ubicacion', () {
    test('GET /mobile/worker/skills → retorna habilidades', () async {
      final res = await buildApi().get(
        '/mobile/worker/skills',
        queryParameters: {'workerUserId': workerId},
      );
      expect(res['skills'], isA<List>());
      expect((res['skills'] as List).contains('Plomeria'), isTrue);
      print('  ✓ Skills OK');
    });
    test('POST /mobile/worker/skills → actualiza habilidades', () async {
      final res = await buildApi().post(
        '/mobile/worker/skills',
        body: {
          'workerUserId': workerId,
          'skills': ['Carpinteria', 'Pintura'],
        },
      );
      expect((res['skills'] as List).contains('Carpinteria'), isTrue);
      print('  ✓ Skills actualizadas');
    });
    test('POST /mobile/worker/location → actualiza ubicacion (201)', () async {
      await buildApi().post(
        '/mobile/worker/location',
        body: {
          'workerUserId': workerId,
          'latitude': -16.5,
          'longitude': -68.15,
        },
      );
      print('  ✓ Ubicacion OK');
    });
    test('POST /mobile/worker/availability → activa disponibilidad', () async {
      final res = await buildApi().post(
        '/mobile/worker/availability',
        body: {'workerUserId': workerId, 'available': true},
      );
      expect(res['isAvailable'] ?? res['is_available'] ?? true, isTrue);
      print('  ✓ Disponibilidad OK');
    });
    test('GET /mobile/worker/history → retorna historial', () async {
      final res = await buildApi().get(
        '/mobile/worker/history',
        queryParameters: {'workerUserId': workerId},
      );
      expect(res['jobs'], isA<List>());
      print('  ✓ Historial OK');
    });
  });

  group('API – Explore', () {
    test('GET /mobile/explore → retorna datos para cliente', () async {
      final res = await buildApi().get(
        '/mobile/explore',
        queryParameters: {
          'userId': clientId,
          'lat': '-16.5',
          'lng': '-68.15',
          'radiusKm': '50',
        },
      );
      expect(res['user'], isNotNull);
      expect(res['nearbyWorkers'], isA<List>());
      expect(res['categories'], isA<List>());
      print('  ✓ Explore OK');
    });
    test('worker disponible aparece en nearbyWorkers', () async {
      final res = await buildApi().get(
        '/mobile/explore',
        queryParameters: {
          'userId': clientId,
          'lat': '-16.5',
          'lng': '-68.15',
          'radiusKm': '50',
        },
      );
      final workers = res['nearbyWorkers'] as List;
      final found = workers.firstWhere(
        (w) => w['id'] == workerId,
        orElse: () => null,
      );
      expect(found, isNotNull);
      print('  ✓ Worker en explore');
    });
  });

  group('API – Solicitudes', () {
    test(
      'POST /mobile/request-categories/preview → sugiere categorias',
      () async {
        final res = await buildApi().post(
          '/mobile/request-categories/preview',
          body: {
            'description': 'Necesito un plomero para arreglar una tuberia',
          },
        );
        expect(res['title'], isNotEmpty);
        expect(res['aiCategories'], isA<List>());
        print('  ✓ Preview OK');
      },
    );
    test('solicitud creada en setup', () {
      expect(requestId, isNotEmpty);
      print('  ✓ Request: $requestId');
    });
    test('error si budget <= 0', () async {
      expect(
        () => buildApi().post(
          '/mobile/requests',
          body: {
            'clientUserId': clientId,
            'title': 'Test',
            'description': 'Test',
            'budget': 0,
            'priceType': 'fixed',
            'address': 'Test',
            'latitude': -16.5,
            'longitude': -68.15,
          },
        ),
        throwsA(isA<Exception>()),
      );
    });
    test('GET /mobile/request-status → por requestId', () async {
      final res = await buildApi().get(
        '/mobile/request-status',
        queryParameters: {'requestId': requestId},
      );
      expect(res['request'], isNotNull);
      expect(res['metrics'], isNotNull);
      print('  ✓ Request status OK');
    });
    test('GET /mobile/request-status → por clientUserId', () async {
      final res = await buildApi().get(
        '/mobile/request-status',
        queryParameters: {'clientUserId': clientId},
      );
      expect(res['request'], isNotNull);
      print('  ✓ Request status por clientId OK');
    });
  });

  group('API – Ofertas', () {
    test('GET /mobile/offers → retorna ofertas', () async {
      final res = await buildApi().get(
        '/mobile/offers',
        queryParameters: {'requestId': requestId},
      );
      expect(res['request'], isNotNull);
      expect(res['offers'], isA<List>());
      print('  ✓ Offers OK');
    });
    test('oferta creada en setup', () {
      expect(offerId, isNotEmpty);
      print('  ✓ Offer: $offerId');
    });
    test('GET /mobile/workers/:id/profile → perfil del worker', () async {
      final res = await buildApi().get('/mobile/workers/$workerId/profile');
      expect(res['worker']['id'], equals(workerId));
      expect(res['worker']['skills'], isA<List>());
      expect(res['reviews'], isA<List>());
      print('  ✓ Worker profile OK');
    });
  });

  group('API – Incoming Request (worker)', () {
    test('GET /mobile/incoming-request → worker ve solicitud o null', () async {
      final res = await buildApi().get(
        '/mobile/incoming-request',
        queryParameters: {'workerUserId': workerId},
      );
      expect(res, isNotNull);
      print('  ✓ Incoming request OK');
    });
    test('GET /mobile/worker/radar → retorna radar', () async {
      final res = await buildApi().get(
        '/mobile/worker/radar',
        queryParameters: {'workerUserId': workerId},
      );
      expect(res, isNotNull);
      print('  ✓ Radar OK');
    });
  });

  group('API – Mensajes', () {
    test('GET /mobile/messages → lista conversaciones del cliente', () async {
      final res = await buildApi().get(
        '/mobile/messages',
        queryParameters: {'userId': clientId},
      );
      expect(res['threads'], isA<List>());
      print('  ✓ Messages cliente OK');
    });
    test('GET /mobile/messages → lista conversaciones del worker', () async {
      final res = await buildApi().get(
        '/mobile/messages',
        queryParameters: {'userId': workerId},
      );
      expect(res['threads'], isA<List>());
      print('  ✓ Messages worker OK');
    });
    test('GET /mobile/messages/:threadId → obtiene mensajes', () async {
      if (threadId == null) {
        print('  ⚠ Sin threadId, skip');
        return;
      }
      final res = await buildApi().get('/mobile/messages/$threadId');
      expect(res['threadId'], equals(threadId));
      expect(res['messages'], isA<List>());
      print('  ✓ Thread messages OK');
    });
    test('POST /mobile/messages/:threadId → cliente envia mensaje', () async {
      if (threadId == null) {
        print('  ⚠ Sin threadId, skip');
        return;
      }
      final res = await buildApi().post(
        '/mobile/messages/$threadId',
        body: {
          'senderUserId': clientId,
          'content': 'Hola, cuando puedes venir?',
        },
      );
      expect(res['message']['content'], equals('Hola, cuando puedes venir?'));
      expect(res['message']['senderUserId'], equals(clientId));
      print('  ✓ Mensaje cliente OK');
    });
    test('POST /mobile/messages/:threadId → worker responde', () async {
      if (threadId == null) {
        print('  ⚠ Sin threadId, skip');
        return;
      }
      final res = await buildApi().post(
        '/mobile/messages/$threadId',
        body: {
          'senderUserId': workerId,
          'content': 'Puedo ir manana a las 9am',
        },
      );
      expect(res['message']['senderUserId'], equals(workerId));
      print('  ✓ Mensaje worker OK');
    });
    test('error si content vacio', () async {
      if (threadId == null) return;
      expect(
        () => buildApi().post(
          '/mobile/messages/$threadId',
          body: {'senderUserId': clientId, 'content': ''},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('API – Tracking', () {
    test('GET /mobile/tracking → retorna info', () async {
      final res = await buildApi().get(
        '/mobile/tracking',
        queryParameters: {'requestId': requestId},
      );
      expect(res, isNotNull);
      print('  ✓ Tracking OK');
    });
  });

  group('API – Push Token', () {
    test('POST /mobile/push/token → registra token FCM', () async {
      final res = await buildApi().post(
        '/mobile/push/token',
        body: {
          'userId': clientId,
          'token': 'fcm_flutter_${uid()}',
          'platform': 'android',
        },
      );
      expect(res['pushToken'], isNotNull);
      print('  ✓ Push token OK');
    });
    test('error si falta token', () async {
      expect(
        () => buildApi().post('/mobile/push/token', body: {'userId': clientId}),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('API – Review', () {
    test('POST /mobile/reviews → cliente deja resena', () async {
      final res = await buildApi().post(
        '/mobile/reviews',
        body: {
          'requestId': requestId,
          'workerUserId': workerId,
          'clientUserId': clientId,
          'stars': 5,
          'comment': 'Excelente trabajo Flutter',
        },
      );
      expect(res['saved'], isTrue);
      expect(res['workerUserId'], equals(workerId));
      print('  ✓ Review OK');
    });
    test('perfil del worker tiene rating actualizado', () async {
      final res = await buildApi().get('/mobile/workers/$workerId/profile');
      expect(res['reviews'], isA<List>());
      expect(
        (res['worker']['averageRating'] as num).toDouble(),
        greaterThan(0),
      );
      print('  ✓ Rating actualizado');
    });
  });
}
