import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Size;

import 'package:svoi/main.dart';

void main() {
  testWidgets('Login screen renders and validates empty fields',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SvoiApp());

    expect(find.text('SVOI'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Забыли пароль?'), findsOneWidget);
    expect(find.text('или'), findsOneWidget);
    expect(find.text('Создать аккаунт'), findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);

    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(find.text('Введите email'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
  });
}
