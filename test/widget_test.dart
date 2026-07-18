import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/app.dart';
import 'package:lumo/data.dart';
import 'package:lumo/pages/chat_page.dart';
import 'package:lumo/splash_screen.dart';
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
    await tester.pumpWidget(const LumoApp(showSplash: false));
    expect(find.text(notices.first.title), findsOneWidget);

    final homeDock = find.byKey(const ValueKey('dock-首页'));
    expect(homeDock, findsOneWidget);
    expect(
        tester.getSemantics(homeDock),
        isSemantics(
            label: '首页', isButton: true, isSelected: true, hasTapAction: true));

    await tester.tap(find.byKey(const ValueKey('dock-智能体')));
    await tester.pumpAndSettle();
    expect(find.text('选择一位陪伴者延续对话'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dock-探索')));
    await tester.pumpAndSettle();
    expect(find.text('认识这里的陪伴者'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dock-个人')));
    await tester.pumpAndSettle();
    expect(find.text('游客用户'), findsOneWidget);
    expect(find.text('陪伴偏好'), findsOneWidget);

    await tester.tap(homeDock);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(homeDock));
    await gesture
        .moveTo(tester.getCenter(find.byKey(const ValueKey('dock-个人'))));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('游客用户'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('primary surfaces remain usable on a small phone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(const LumoApp(showSplash: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(notices.first.title));
    await tester.pumpAndSettle();
    expect(find.text('知道了'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('知道了'),
      240,
      scrollable: find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable)),
    );
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dock-探索')));
    await tester.pumpAndSettle();
    expect(find.text('找到与你同频的人'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode and chat controls expose clear states',
      (tester) async {
    tester.view.physicalSize = const Size(700, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const LumoApp(showSplash: false));
    await tester.tap(find.byKey(const ValueKey('dock-个人')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('深色模式'), 160);
    await tester.drag(find.byKey(const PageStorageKey('profile-scroll')),
        const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();
    expect(find.text('浅色模式'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('浅色模式'))).brightness,
        Brightness.dark);

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-settings')), -180);
    await tester.tap(find.byKey(const ValueKey('profile-settings')));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('账号与隐私'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('当前版本：1.3.0'), 200);
    expect(find.text('当前版本：1.3.0'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLumoTheme(Brightness.dark),
        home: ChatPage(companion: companions.first, heroTag: 'test-chat'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
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

  testWidgets('splash waits gently and exits when startup is ready',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
          home: LumoSplash(ready: false, onFinished: () => finished = true)),
    );
    expect(find.text('Lumo'), findsOneWidget);
    expect(find.text('点亮你的每一刻'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.bySemanticsLabel('Lumo 正在准备陪伴，请稍候'), findsOneWidget);
    expect(finished, isFalse);

    await tester.pumpWidget(
      MaterialApp(
          home: LumoSplash(ready: true, onFinished: () => finished = true)),
    );
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });
}
