import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/session/session_credentials.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';

class _Remote implements AuthRemoteDataSource {
  final response = <String, dynamic>{'token': 'signed-server-token', 'user': {
    'id': 'account', 'type': 'client', 'firstName': 'Ana', 'email': 'ana@example.com',
  }};
  @override
  Future<Map<String, dynamic>> login({required String identifier, required String password}) async => response;
  @override
  Future<Map<String, dynamic>> checkIdentifier({required String identifier}) async => {'exists': true};
  @override
  Future<Map<String, dynamic>> register({required String role, required String email, String? phone, String? countryCode,
    String? ciNumber, required String firstName, String? lastName, required String password}) async => response;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() { SharedPreferences.setMockInitialValues({}); SessionCredentials.accessToken = null; });
  tearDown(() async => SessionStore.clear());
  test('registration stores the signed token for HTTP, sockets and background service', () async {
    await AuthRepositoryImpl(_Remote()).register(role: 'client', email: 'ana@example.com', firstName: 'Ana', password: 'secret123');
    expect(SessionCredentials.accessToken, 'signed-server-token');
    expect((await SharedPreferences.getInstance()).getString('session_access_token'), 'signed-server-token');
  });
  test('login restores the signed token', () async {
    await AuthRepositoryImpl(_Remote()).login(identifier: 'ana@example.com', password: 'secret123');
    expect(SessionCredentials.headers['Authorization'], 'Bearer signed-server-token');
  });
}
