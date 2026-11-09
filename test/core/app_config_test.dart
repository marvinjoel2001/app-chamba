import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/app_config.dart';

void main() {
  test('una versión de tienda sin API_BASE_URL usa el servidor de producción', () {
    expect(
      AppConfig.orProductionFor('', 'https://prod/api', release: true),
      'https://prod/api',
    );
    expect(
      AppConfig.orProductionFor('https://otro/api', 'https://prod/api', release: true),
      'https://otro/api',
    );
    // En debug se respeta vacía para notar el olvido.
    expect(AppConfig.orProductionFor('', 'https://prod/api', release: false), '');
  });
}
