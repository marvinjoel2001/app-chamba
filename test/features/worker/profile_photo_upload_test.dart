import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/worker/data/datasources/worker_remote_datasource.dart';
import 'package:mobile/features/worker/data/repositories/worker_repository_impl.dart';

/// Solo implementa la subida de la foto de perfil; el resto no se usa aquí.
class _FakeRemote implements WorkerRemoteDataSource {
  final calls = <Map<String, String>>[];

  @override
  Future<Map<String, dynamic>> uploadProfilePhoto({
    required String userId,
    required String imageBase64,
  }) async {
    calls.add({'userId': userId, 'imageBase64': imageBase64});
    return {
      'user': {
        'id': userId,
        'profilePhotoUrl':
            'https://res.cloudinary.com/chamba/image/upload/v1/chamba/profile/nueva.jpg',
      },
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('la foto de perfil se manda en base64 al backend y vuelve la URL nueva',
      () async {
    final remote = _FakeRemote();
    final result = await WorkerRepositoryImpl(remote).uploadProfilePhoto(
      userId: 'u1',
      imageBase64: 'data:image/jpeg;base64,AAAA',
    );

    expect(remote.calls, [
      {'userId': 'u1', 'imageBase64': 'data:image/jpeg;base64,AAAA'}
    ]);
    expect(
      result.fold(onSuccess: (url) => url, onFailure: (_) => 'error'),
      'https://res.cloudinary.com/chamba/image/upload/v1/chamba/profile/nueva.jpg',
    );
    expect(result, isA<Success<String?>>());
  });
}
