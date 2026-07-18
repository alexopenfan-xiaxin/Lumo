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

  test(
    'passes download, progress, permission, and install channel arguments',
    () async {
      const channel = MethodChannel('app.lumo.companion/external_url');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'canRequestPackageInstalls' => true,
              'downloadApk' => 42,
              'downloadStatus' => {
                'state': 'downloading',
                'received': 50,
                'total': 100,
                'reason': null,
              },
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final url = Uri.parse(
        'https://github.com/alexopenfan-xiaxin/Lumo/releases/download/v1.3.0-build.55/app-release.apk',
      );
      final checker = UpdateChecker();
      expect(await checker.canRequestPackageInstalls(), isTrue);
      await checker.openInstallSettings();
      final id = await checker.startDownload(url);
      final status = await checker.downloadStatus(id);
      expect(status.progress, 0.5);
      expect(status.isComplete, isFalse);
      await checker.installDownloadedApk(id);

      expect(calls.map((call) => call.method), [
        'canRequestPackageInstalls',
        'openInstallSettings',
        'downloadApk',
        'downloadStatus',
        'installDownloadedApk',
      ]);
      expect(calls.map((call) => call.arguments), [
        null,
        null,
        {'url': url.toString()},
        {'id': 42},
        {'id': 42},
      ]);
    },
  );
}
