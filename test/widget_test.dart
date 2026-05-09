// Tests de widgets: verifica formularios, validaciones y UI de la app Flutter.
// No requiere backend corriendo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';

void main() {
  group('Widget – LoginScreen: validaciones de formulario', () {
    testWidgets('muestra campo de correo/telefono y boton Siguiente', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );
      await tester.pump();
      expect(find.text('Correo o teléfono'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
    });

    testWidgets('muestra error si campo vacio al presionar Siguiente', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );
      await tester.pump();
      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      expect(find.text('Ingresa tu correo o teléfono'), findsOneWidget);
    });

    testWidgets('puede ingresar texto en campo identifier', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
      await tester.pump();
      expect(find.text('test@test.com'), findsOneWidget);
    });

    testWidgets('boton Volver esta presente', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );
      await tester.pump();
      expect(find.text('Volver'), findsOneWidget);
    });

    testWidgets('boton Crear cuenta esta presente', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );
      await tester.pump();
      expect(find.text('Crear cuenta'), findsOneWidget);
    });

    testWidgets('titulo Iniciar sesion esta presente', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );
      await tester.pump();
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });
  });

  group('Widget – RegisterScreen: validaciones de formulario', () {
    testWidgets('muestra todos los campos del formulario', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Correo'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Crear cuenta'), findsOneWidget);
    });

    testWidgets('muestra chips de rol cliente/trabajador', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      expect(find.text('Quiero contratar'), findsOneWidget);
      expect(find.text('Quiero trabajar'), findsOneWidget);
    });

    testWidgets('puede cambiar rol a trabajador', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      await tester.tap(find.text('Quiero trabajar'));
      await tester.pump();
      expect(find.text('Registro trabajador'), findsOneWidget);
    });

    testWidgets('rol cliente es el default', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      expect(find.text('Registro contratante'), findsOneWidget);
    });

    testWidgets('muestra error si nombre vacio al enviar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      expect(find.text('Ingresa tu nombre'), findsOneWidget);
    });

    testWidgets('muestra error si correo vacio al enviar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Juan',
      );
      await tester.pump();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      expect(find.text('Ingresa tu correo'), findsOneWidget);
    });

    testWidgets('muestra error si contrasena muy corta', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Juan',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'juan@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        '123',
      );
      await tester.pump();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      expect(find.text('Mínimo 4 caracteres'), findsOneWidget);
    });

    testWidgets('puede ingresar todos los campos correctamente', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Juan',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Apellido (opcional)'),
        'Perez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'juan@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Teléfono (opcional)'),
        '70000000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'pass1234',
      );
      await tester.pump();
      expect(find.text('Juan'), findsOneWidget);
      expect(find.text('juan@test.com'), findsOneWidget);
    });

    testWidgets('boton Ya tengo cuenta esta presente', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      expect(find.text('Ya tengo cuenta'), findsOneWidget);
    });

    testWidgets('campo apellido es opcional (no muestra error si vacio)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Juan',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'juan@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'pass1234',
      );
      await tester.pump();
      // No error for empty apellido
      expect(find.text('Ingresa tu apellido'), findsNothing);
    });
  });
}
