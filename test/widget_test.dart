import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/screens/planner_screen.dart';

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(ListView).first,
    const Offset(0, -250),
  );
  await tester.pump();
}

void main() {
  testWidgets('planlayıcı ekranı temel bölümleri gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));

    expect(find.text('Gezi planla'), findsOneWidget);
    expect(find.text('Nereye gitmek istiyorsun?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await _scrollTo(tester, find.text('Ne zaman seyahat edeceksin?'));

    expect(find.text('Ne zaman seyahat edeceksin?'), findsOneWidget);
  });

  testWidgets('ön seçili destinasyon alanı doldurur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlannerScreen(initialDestination: 'Kyoto')),
    );

    expect(find.textContaining('seçildi'), findsOneWidget);
  });

  testWidgets('destinasyon seçmeden plan oluşturma uyarı verir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));

    final button = find.text('Gezi planımı oluştur');
    await _scrollTo(tester, button);
    await tester.tap(button);
    await tester.pump();

    expect(
      find.text('Önce gitmek istediğin destinasyonu seç.'),
      findsOneWidget,
    );
  });
}
