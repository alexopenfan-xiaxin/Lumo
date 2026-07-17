import 'dart:convert';
import 'dart:io';

class AiChatClient {
  AiChatClient({String? endpoint}) : _endpoint = endpoint ?? const String.fromEnvironment('LUMO_AI_ENDPOINT');

  final String _endpoint;

  Future<String> reply(List<AiChatMessage> messages) async {
    if (_endpoint.isEmpty) throw const AiChatException('喵喵的 AI 服务还没有部署完成。');
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'agentId': 'meow',
        'messages': messages.map((message) => message.toJson()).toList(),
      }));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) throw const AiChatException('喵喵暂时没能接上，稍后再试试吧。');
      final reply = (jsonDecode(body) as Map<String, dynamic>)['reply'];
      if (reply is! String || reply.trim().isEmpty) throw const AiChatException('喵喵暂时没能接上，稍后再试试吧。');
      return reply.trim();
    } on SocketException {
      throw const AiChatException('网络好像开小差了，检查连接后再试试吧。');
    } on FormatException {
      throw const AiChatException('喵喵暂时没能接上，稍后再试试吧。');
    } finally {
      client.close(force: true);
    }
  }
}

class AiChatException implements Exception {
  const AiChatException(this.message);

  final String message;
}

class AiChatMessage {
  const AiChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}
