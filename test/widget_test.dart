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

    expect(find.bySemanticsLabel('首页'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('智能体'));
    await tester.pumpAndSettle();
    expect(find.text('选择一位陪伴者延续对话'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('探索'));
    await tester.pumpAndSettle();
    expect(find.text('认识这里的陪伴者'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('设置'));
    await tester.pumpAndSettle();
    expect(find.text('让陪伴更贴近你的习惯'), findsOneWidget);
  });
}
