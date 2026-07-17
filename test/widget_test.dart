import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('primary navigation and chat flow work', (tester) async {
    await tester.pumpWidget(const LumoApp());
    expect(find.text('七日微光计划'), findsWidgets);

    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('和喵喵延续每一段对话'), findsOneWidget);

    await tester.tap(find.text('喵喵').first);
    await tester.pumpAndSettle();
    expect(find.text('你来啦？我、我刚好有空而已喔。今天想让喵喵陪你聊点什么？'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '今天有一点累');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    expect(find.text('今天有一点累'), findsOneWidget);
  });
}
