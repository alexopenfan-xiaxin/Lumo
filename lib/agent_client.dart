import 'dart:convert';
import 'dart:io';

import 'data.dart';

class AgentClient {
  const AgentClient({String? endpoint})
    : _endpoint = endpoint ?? const String.fromEnvironment('LUMO_AI_ENDPOINT');

  final String _endpoint;

  Future<List<Companion>> fetchAgents() async {
    if (_endpoint.isEmpty) throw const AgentCatalogException('智能体服务还没有部署完成。');
    final client = HttpClient();
    try {
      final endpoint = Uri.parse(_endpoint);
      final request = await client.getUrl(
        endpoint.replace(path: '/agents', query: null),
      );
      final response = await request.close();
      final decoded =
          jsonDecode(await utf8.decoder.bind(response).join())
              as Map<String, dynamic>;
      if (response.statusCode != HttpStatus.ok || decoded['agents'] is! List) {
        throw const AgentCatalogException('智能体列表暂时不可用。');
      }
      final rawAgents = decoded['agents'] as List;
      if (rawAgents.any((agent) => agent is! Map)) {
        throw const AgentCatalogException('智能体配置暂时无法读取。');
      }
      return rawAgents
          .map(
            (agent) =>
                Companion.fromJson(Map<String, dynamic>.from(agent as Map)),
          )
          .toList(growable: false);
    } on SocketException {
      throw const AgentCatalogException('网络好像开小差了，连接后重试吧。');
    } on FormatException {
      throw const AgentCatalogException('智能体配置暂时无法读取。');
    } on TypeError {
      throw const AgentCatalogException('智能体配置暂时无法读取。');
    } on RangeError {
      throw const AgentCatalogException('智能体配置暂时无法读取。');
    } finally {
      client.close(force: true);
    }
  }
}

class AgentCatalogException implements Exception {
  const AgentCatalogException(this.message);

  final String message;
}
