import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'app_info.dart';

class ReleaseUpdate {
  const ReleaseUpdate({required this.version, required this.url});

  final String version;
  final Uri url;
}

class UpdateChecker {
  static const _latestRelease = 'https://api.github.com/repos/alexopenfan-xiaxin/Lumo/releases/latest';
  static const _channel = MethodChannel('app.lumo.companion/external_url');

  Future<ReleaseUpdate?> check() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_latestRelease));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'Lumo/$appVersion');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) throw const HttpException('Unable to check for updates');
      final body = jsonDecode(await utf8.decoder.bind(response).join());
      if (body is! Map<String, dynamic>) throw const FormatException('Invalid release');
      final tag = body['tag_name'];
      final url = body['html_url'];
      if (tag is! String || url is! String) throw const FormatException('Invalid release');
      final match = RegExp(r'^v(\d+\.\d+\.\d+)-build\.\d+$').firstMatch(tag);
      final releaseUrl = Uri.tryParse(url);
      if (match == null || releaseUrl == null || releaseUrl.scheme != 'https' || releaseUrl.host != 'github.com') {
        throw const FormatException('Invalid release');
      }
      final version = match.group(1)!;
      return compareVersions(version, appVersion) > 0 ? ReleaseUpdate(version: version, url: releaseUrl) : null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> openDownload(Uri url) => _channel.invokeMethod<void>('openUrl', url.toString());
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
