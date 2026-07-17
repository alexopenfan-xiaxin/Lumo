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
    await tester.pump();
    expect(find.text('喵喵'), findsWidgets);
  });
}
