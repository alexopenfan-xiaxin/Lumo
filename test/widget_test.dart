import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('floating navigation reaches every primary page', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(const LumoApp());
    expect(find.text('七日微光计划'), findsWidgets);

    final homeDock = find.byKey(const ValueKey('dock-首页'));
    expect(homeDock, findsOneWidget);
    expect(tester.getSemantics(homeDock), containsSemantics(label: '首页', isButton: true, isSelected: true, hasTapAction: true));

    await tester.tap(find.byKey(const ValueKey('dock-智能体')));
    await tester.pumpAndSettle();
    expect(find.text('选择一位陪伴者延续对话'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dock-探索')));
    await tester.pumpAndSettle();
    expect(find.text('认识这里的陪伴者'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dock-设置')));
    await tester.pumpAndSettle();
    expect(find.text('让陪伴更贴近你的习惯'), findsOneWidget);
  });
}
