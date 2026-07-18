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
}
