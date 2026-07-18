import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'app_info.dart';

class ReleaseUpdate {
  const ReleaseUpdate({
    required this.version,
    required this.build,
    required this.url,
  });

  final String version;
  final int build;
  final Uri url;
}

class UpdateChecker {
  static const _latestDownload =
      'https://github.com/alexopenfan-xiaxin/Lumo/releases/latest/download/app-release.apk';
  static const _maxApkBytes = 250 * 1024 * 1024;
  static const _channel = MethodChannel('app.lumo.companion/external_url');

  Future<ReleaseUpdate?> check() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'Lumo/$appVersion';
    try {
      final latest = Uri.parse(_latestDownload);
      final request = await client.getUrl(latest);
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (!const {301, 302, 303, 307, 308}.contains(response.statusCode) ||
          location == null) {
        throw HttpException('检查更新失败（HTTP ${response.statusCode}）');
      }
      return releaseFromDownloadUrl(
        latest.resolve(location),
        appVersion,
        appReleaseBuild,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> canRequestPackageInstalls() async =>
      await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;

  Future<void> openInstallSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');

  Future<String> updateDirectory() async =>
      await _channel.invokeMethod<String>('updateDirectory') ??
      (throw PlatformException(
        code: 'download_path_missing',
        message: '无法创建更新目录。',
      ));

  Future<File> download(
    Uri url,
    void Function(int received, int total) onProgress, {
    Directory? destination,
  }) async {
    final directory = destination ?? Directory(await updateDirectory());
    await directory.create(recursive: true);
    final apk = File(
      '${directory.path}${Platform.pathSeparator}lumo-update.apk',
    );
    final partial = File('${apk.path}.part');
    if (await partial.exists()) await partial.delete();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'Lumo/$appVersion';
    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.android.package-archive, application/octet-stream',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('更新下载失败（HTTP ${response.statusCode}）');
      }
      final total = response.contentLength;
      if (total > _maxApkBytes) throw const HttpException('更新包超过 250 MB 限制');

      sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        received += chunk.length;
        if (received > _maxApkBytes) {
          throw const HttpException('更新包超过 250 MB 限制');
        }
        sink.add(chunk);
        onProgress(received, total);
      }
      await sink.close();
      sink = null;
      if (received == 0 || (total > 0 && received != total)) {
        throw const HttpException('更新包下载不完整');
      }
      final signature = await partial
          .openRead(0, 4)
          .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
      if (signature.length != 4 ||
          signature[0] != 0x50 ||
          signature[1] != 0x4b ||
          signature[2] != 0x03 ||
          signature[3] != 0x04) {
        throw const FormatException('下载内容不是有效的 APK');
      }
      if (await apk.exists()) await apk.delete();
      return partial.rename(apk.path);
    } finally {
      await sink?.close();
      if (await partial.exists()) await partial.delete();
      client.close(force: true);
    }
  }

  Future<void> installApk(String path) =>
      _channel.invokeMethod<void>('installApk', {'path': path});
}

ReleaseUpdate? releaseFromDownloadUrl(
  Uri url,
  String installedVersion,
  int installedBuild,
) {
  final match = RegExp(
    r'^/alexopenfan-xiaxin/Lumo/releases/download/v(\d+\.\d+\.\d+)-build\.(\d+)/app-release\.apk$',
  ).firstMatch(url.path);
  if (url.scheme != 'https' || url.host != 'github.com' || match == null) {
    throw const FormatException('Invalid release download URL');
  }
  final version = match.group(1)!;
  final build = int.parse(match.group(2)!);
  return isNewerRelease(version, build, installedVersion, installedBuild)
      ? ReleaseUpdate(version: version, build: build, url: url)
      : null;
}

int compareVersions(String left, String right) {
  final leftParts = left.split('.').map(int.parse).toList();
  final rightParts = right.split('.').map(int.parse).toList();
  for (var index = 0; index < 3; index++) {
    final comparison = leftParts[index].compareTo(rightParts[index]);
    if (comparison != 0) return comparison;
  }
  return 0;
}

bool isNewerRelease(
  String releaseVersion,
  int releaseBuild,
  String installedVersion,
  int installedBuild,
) {
  final versionComparison = compareVersions(releaseVersion, installedVersion);
  return versionComparison > 0 ||
      (versionComparison == 0 && releaseBuild > installedBuild);
}
