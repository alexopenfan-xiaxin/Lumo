import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'app_info.dart';

class ReleaseUpdate {
  const ReleaseUpdate(
      {required this.version, required this.build, required this.url});

  final String version;
  final int build;
  final Uri url;
}

class UpdateDownloadStatus {
  const UpdateDownloadStatus(
      {required this.state,
      required this.received,
      required this.total,
      this.reason});

  final String state;
  final int received;
  final int total;
  final int? reason;

  bool get isComplete => state == 'success';
  bool get isFailed => state == 'failed';
  double? get progress =>
      total > 0 ? (received / total).clamp(0, 1).toDouble() : null;

  factory UpdateDownloadStatus.fromMap(Map<Object?, Object?> map) =>
      UpdateDownloadStatus(
        state: map['state']! as String,
        received: map['received']! as int,
        total: map['total']! as int,
        reason: map['reason'] as int?,
      );
}

class UpdateChecker {
  static const _latestRelease =
      'https://api.github.com/repos/alexopenfan-xiaxin/Lumo/releases/latest';
  static const _channel = MethodChannel('app.lumo.companion/external_url');

  Future<ReleaseUpdate?> check() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_latestRelease));
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'Lumo/$appVersion');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok)
        throw const HttpException('Unable to check for updates');
      final body = jsonDecode(await utf8.decoder.bind(response).join());
      if (body is! Map<String, dynamic>)
        throw const FormatException('Invalid release');
      final tag = body['tag_name'];
      final assets = body['assets'];
      if (tag is! String || assets is! List)
        throw const FormatException('Invalid release');
      final asset = assets
          .whereType<Map<String, dynamic>>()
          .where((item) => item['name'] == 'app-release.apk')
          .firstOrNull;
      final url = asset?['browser_download_url'];
      if (url is! String) throw const FormatException('Missing APK');
      final match = RegExp(r'^v(\d+\.\d+\.\d+)-build\.(\d+)$').firstMatch(tag);
      final releaseUrl = Uri.tryParse(url);
      if (match == null ||
          releaseUrl == null ||
          releaseUrl.scheme != 'https' ||
          releaseUrl.host != 'github.com') {
        throw const FormatException('Invalid release');
      }
      final version = match.group(1)!;
      final build = int.parse(match.group(2)!);
      return isNewerRelease(version, build, appVersion, appReleaseBuild)
          ? ReleaseUpdate(version: version, build: build, url: releaseUrl)
          : null;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> canRequestPackageInstalls() async =>
      await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;

  Future<void> openInstallSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');

  Future<int> startDownload(Uri url) async =>
      await _channel
          .invokeMethod<int>('downloadApk', {'url': url.toString()}) ??
      (throw PlatformException(code: 'download_failed'));

  Future<UpdateDownloadStatus> downloadStatus(int id) async {
    final status = await _channel
        .invokeMapMethod<Object?, Object?>('downloadStatus', {'id': id});
    if (status == null)
      throw PlatformException(code: 'download_missing', message: '无法读取更新下载状态。');
    return UpdateDownloadStatus.fromMap(status);
  }

  Future<void> installDownloadedApk(int id) =>
      _channel.invokeMethod<void>('installDownloadedApk', {'id': id});
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

bool isNewerRelease(String releaseVersion, int releaseBuild,
    String installedVersion, int installedBuild) {
  final versionComparison = compareVersions(releaseVersion, installedVersion);
  return versionComparison > 0 ||
      (versionComparison == 0 && releaseBuild > installedBuild);
}
