import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/update_checker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compares semantic release versions', () {
    expect(compareVersions('1.2.0', '1.1.0'), isPositive);
    expect(compareVersions('1.1.0', '1.1.0'), isZero);
    expect(compareVersions('1.0.9', '1.1.0'), isNegative);
  });

  test('compares release builds after semantic versions match', () {
    expect(isNewerRelease('1.3.0', 38, '1.3.0', 37), isTrue);
    expect(isNewerRelease('1.3.0', 37, '1.3.0', 37), isFalse);
    expect(isNewerRelease('1.2.9', 99, '1.3.0', 1), isFalse);
  });

  test('accepts only the expected GitHub release download URL', () {
    final update = releaseFromDownloadUrl(
      Uri.parse(
        'https://github.com/alexopenfan-xiaxin/Lumo/releases/download/v1.3.0-build.55/app-release.apk',
      ),
      '1.3.0',
      54,
    );
    expect(update?.version, '1.3.0');
    expect(update?.build, 55);
    expect(
      () => releaseFromDownloadUrl(
        Uri.parse(
          'https://example.com/alexopenfan-xiaxin/Lumo/releases/download/v1.3.0-build.55/app-release.apk',
        ),
        '1.3.0',
        54,
      ),
      throwsFormatException,
    );
  });

  test(
    'passes permission, update directory, and install channel arguments',
    () async {
      const channel = MethodChannel('app.lumo.companion/external_url');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'canRequestPackageInstalls' => true,
              'updateDirectory' => '/cache/updates',
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final checker = UpdateChecker();
      expect(await checker.canRequestPackageInstalls(), isTrue);
      await checker.openInstallSettings();
      expect(await checker.updateDirectory(), '/cache/updates');
      await checker.installApk('/cache/updates/lumo-update.apk');

      expect(calls.map((call) => call.method), [
        'canRequestPackageInstalls',
        'openInstallSettings',
        'updateDirectory',
        'installApk',
      ]);
      expect(calls.map((call) => call.arguments), [
        null,
        null,
        null,
        {'path': '/cache/updates/lumo-update.apk'},
      ]);
    },
  );

  test('downloads an APK into the app update directory with progress', () async {
    final directory = await Directory.systemTemp.createTemp('lumo-update-test-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    server.listen((request) async {
      const apkBytes = <int>[0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4];
      request.response.contentLength = apkBytes.length;
      request.response.add(apkBytes);
      await request.response.close();
    });

    const channel = MethodChannel('app.lumo.companion/external_url');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'updateDirectory'
              ? directory.path
              : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final progress = <(int, int)>[];
    final apk = await UpdateChecker().download(
      Uri.parse('http://127.0.0.1:${server.port}/app-release.apk'),
      (received, total) => progress.add((received, total)),
    );

    expect(await apk.readAsBytes(), <int>[0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4]);
    expect(progress.last, (8, 8));
  });
}
