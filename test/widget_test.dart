import 'package:flutter_test/flutter_test.dart';
import 'package:alacena_practica/main.dart';

void main() {
  testWidgets('La aplicación inicia correctamente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AlacenaSmart());

    expect(find.text('Alacena Smart'), findsOneWidget);
  });
}