import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/app.dart';
import 'package:lumo/data.dart';
import 'package:lumo/pages/chat_page.dart';
import 'package:lumo/theme.dart';
import 'package:lumo/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('floating navigation reaches every primary page', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const LumoApp());
    expect(find.text('Lumo 1.3.0 更新'), findsWidgets);

    final homeDock = find.byKey(const ValueKey('dock-首页'));
    expect(homeDock, findsOneWidget);
    expect(tester.getSemantics(homeDock), isSemantics(label: '首页', isButton: true, isSelected: true, hasTapAction: true));

    await tester.tap(find.byKey(const ValueKey('dock-智能体')));
    await tester.pumpAndSettle();
    expect(find.text('选择一位陪伴者延续对话'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dock-探索')));
    await tester.pumpAndSettle();
    expect(find.text('认识这里的陪伴者'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dock-设置')));
    await tester.pumpAndSettle();
    expect(find.text('让陪伴更贴近你的习惯'), findsOneWidget);

    await tester.tap(homeDock);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(homeDock));
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('dock-设置'))));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('让陪伴更贴近你的习惯'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('primary surfaces remain usable on a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(const LumoApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Lumo 1.3.0 更新'));
    await tester.pumpAndSettle();
    expect(find.text('知道了'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dock-探索')));
    await tester.pumpAndSettle();
    expect(find.text('找到与你同频的人'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode and chat controls expose clear states', (tester) async {
    tester.view.physicalSize = const Size(700, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const LumoApp());
    await tester.tap(find.byKey(const ValueKey('dock-设置')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('设置'))).brightness, Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLumoTheme(Brightness.dark),
        home: ChatPage(companion: companions.first, heroTag: 'test-chat'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('切换到语音输入'), findsOneWidget);
    expect(find.byTooltip('发送'), findsOneWidget);
    expect(find.text('说说此刻的感受…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared motion honors reduced motion', (tester) async {
    Duration? duration;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            duration = lumoMotionDuration(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(duration, Duration.zero);
  });
}
