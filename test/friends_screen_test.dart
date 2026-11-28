import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/screens/friends_screen.dart';

void main() {
  testWidgets('closes the friend request dialog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FriendsScreen())),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.ensureVisible(find.text('Conectar con otros'));
    await tester.tap(find.text('Conectar con otros'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Enviar solicitud de amistad'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'friend@example.com');
    await tester.tap(find.text('Enviar'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Enviar solicitud de amistad'), findsNothing);
  });
}
