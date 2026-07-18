import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/update_checker.dart';

void main() {
  test(
    'downloads an APK into the app update directory with progress',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lumo-update-test-',
      );
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

      final progress = <(int, int)>[];
      final apk = await UpdateChecker().download(
        Uri.parse('http://127.0.0.1:${server.port}/app-release.apk'),
        (received, total) => progress.add((received, total)),
        destination: directory,
      );

      expect(await apk.readAsBytes(), <int>[
        0x50,
        0x4b,
        0x03,
        0x04,
        1,
        2,
        3,
        4,
      ]);
      expect(progress.last, (8, 8));
    },
  );
}
