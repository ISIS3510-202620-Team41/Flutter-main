import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/app.dart';

void main() {
  testWidgets('shows the Figma auth entry screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LlamallaApp());

    expect(find.text('Actividad ya'), findsOneWidget);
    expect(find.text('Qué bueno verte de\nnuevo'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Ingresar con biometría'), findsOneWidget);
    expect(find.text('Crear una cuenta'), findsOneWidget);
  });

  testWidgets('auth provider buttons remain no-op controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LlamallaApp());

    await tester.tap(find.text('Continuar con Google'));
    await tester.tap(find.text('Ingresar con biometría'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pump();

    expect(find.text('Actividad ya'), findsOneWidget);
  });

  testWidgets('opens the account creation screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LlamallaApp());

    await tester.ensureVisible(find.text('Crear una cuenta'));
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Crea tu perfil'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('¿Ya tienes perfil? '), findsOneWidget);
  });
}
