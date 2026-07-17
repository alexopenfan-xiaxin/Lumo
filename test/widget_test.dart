import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/app.dart';

void main() {
  testWidgets('primary navigation and chat flow work', (tester) async {
    await tester.pumpWidget(const LumoApp());
    expect(find.text('七日微光计划'), findsWidgets);

    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('延续一段熟悉的对话'), findsOneWidget);

    await tester.tap(find.text('暖时光').first);
    await tester.pumpAndSettle();
    expect(find.text('我在。今天有什么想慢慢说给我听的？'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '今天有一点累');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    expect(find.text('今天有一点累'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.textContaining('最明显的感受'), findsOneWidget);
  });
}
