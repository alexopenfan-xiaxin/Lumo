import 'dart:convert';
import 'dart:io';

import 'auth_client.dart';

class AiChatClient {
  AiChatClient({String? endpoint, AuthClient? authClient})
    : _endpoint = endpoint ?? const String.fromEnvironment('LUMO_AI_ENDPOINT'),
      _authClient = authClient ?? AuthClient(endpoint: endpoint);

  final String _endpoint;
  final AuthClient _authClient;

  Future<AiChatReply> reply(
    List<AiChatMessage> messages, {
    required String agentId,
    required String summary,
    required List<String> memories,
    void Function(AiChatProgress progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final response = await _streamRequest(client, agentId, {
        'operation': 'chat',
        'stream': true,
        'messages': messages.map((message) => message.toJson()).toList(),
        'summary': summary,
        'memories': memories,
      });
      if (response.statusCode != HttpStatus.ok) {
        final body =
            jsonDecode(await utf8.decoder.bind(response).join())
                as Map<String, dynamic>;
        if (response.statusCode == HttpStatus.requestEntityTooLarge &&
            body['contextLimit'] == true) {
          throw const AiContextLimitException();
        }
        if (response.statusCode == HttpStatus.tooManyRequests) {
          throw AiQuotaException(body['error'] as String? ?? '已达发送限额。');
        }
        if (response.statusCode == HttpStatus.unauthorized) {
          throw const AiChatException('登录已过期，请在设置中重新登录。');
        }
        throw const AiChatException('AI 暂时没能接上，稍后再试试吧。');
      }
      var event = '';
      var text = '';
      var process = '正在整理对话上下文。';
      var sources = const <AiChatSource>[];
      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final data =
              jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
          if (event == 'process') {
            process = data['text'] as String? ?? process;
          } else if (event == 'delta') {
            text += data['text'] as String? ?? '';
          } else if (event == 'done') {
            process = data['process'] as String? ?? process;
            sources = _sources(data['sources']);
          } else if (event == 'error') {
            if (data['contextLimit'] == true) {
              throw const AiContextLimitException();
            }
            throw AiChatException(
              data['message'] as String? ?? 'AI 暂时没能接上，稍后再试试吧。',
            );
          }
          onProgress?.call(
            AiChatProgress(text: text, process: process, sources: sources),
          );
        }
      }
      if (text.trim().isEmpty) throw const AiChatException('AI 暂时没能接上，稍后再试试吧。');
      return AiChatReply(text: text.trim(), process: process, sources: sources);
    } on SocketException {
      throw const AiChatException('网络好像开小差了，检查连接后再试试吧。');
    } on FormatException {
      throw const AiChatException('AI 暂时没能接上，稍后再试试吧。');
    } finally {
      client.close(force: true);
    }
  }

  List<AiChatSource> _sources(Object? sources) => sources is List
      ? sources
            .whereType<Map>()
            .map(
              (source) => AiChatSource(
                title: source['title'] as String? ?? '来源',
                url: source['url'] as String? ?? '',
              ),
            )
            .where((source) => source.url.isNotEmpty)
            .toList()
      : const [];

  Future<HttpClientResponse> _streamRequest(
    HttpClient client,
    String agentId,
    Map<String, dynamic> body,
  ) async {
    if (_endpoint.isEmpty) throw const AiChatException('AI 服务还没有部署完成。');
    final identity = await _authClient.identity();
    final request = await client.postUrl(Uri.parse(_endpoint));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    if (identity.token != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${identity.token}',
      );
    }
    request.write(
      jsonEncode({'agentId': agentId, 'guestId': identity.guestId, ...body}),
    );
    return request.close();
  }

  Future<String> summarize(
    String summary,
    List<AiChatMessage> messages, {
    required String agentId,
  }) async {
    final response = await _request(
      agentId: agentId,
      body: {
        'operation': 'summarize',
        'summary': summary,
        'messages': messages.map((message) => message.toJson()).toList(),
      },
    );
    final nextSummary = response['summary'];
    if (nextSummary is! String) throw const AiChatException('整理早期对话失败，请稍后再试。');
    return nextSummary.trim();
  }

  Future<List<String>> memoryCandidates(
    List<AiChatMessage> messages,
    List<String> memories, {
    required String agentId,
  }) async {
    final response = await _request(
      agentId: agentId,
      body: {
        'operation': 'memory',
        'messages': messages.map((message) => message.toJson()).toList(),
        'memories': memories,
      },
    );
    final candidates = response['candidates'];
    if (candidates is! List) return const [];
    return candidates
        .whereType<String>()
        .map((candidate) => candidate.trim())
        .where((candidate) => candidate.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> _request({
    required String agentId,
    required Map<String, dynamic> body,
  }) async {
    if (_endpoint.isEmpty) throw const AiChatException('AI 服务还没有部署完成。');
    final client = HttpClient();
    try {
      final identity = await _authClient.identity();
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers.contentType = ContentType.json;
      if (identity.token != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${identity.token}',
        );
      }
      request.write(
        jsonEncode({'agentId': agentId, 'guestId': identity.guestId, ...body}),
      );
      final response = await request.close();
      final decoded =
          jsonDecode(await utf8.decoder.bind(response).join())
              as Map<String, dynamic>;
      if (response.statusCode == HttpStatus.requestEntityTooLarge &&
          decoded['contextLimit'] == true) {
        throw const AiContextLimitException();
      }
      if (response.statusCode == HttpStatus.tooManyRequests) {
        throw AiQuotaException(decoded['error'] as String? ?? '已达发送限额。');
      }
      if (response.statusCode == HttpStatus.unauthorized) {
        throw const AiChatException('登录已过期，请在设置中重新登录。');
      }
      if (response.statusCode != HttpStatus.ok) {
        throw const AiChatException('AI 暂时没能接上，稍后再试试吧。');
      }
      return decoded;
    } on SocketException {
      throw const AiChatException('网络好像开小差了，检查连接后再试试吧。');
    } on FormatException {
      throw const AiChatException('AI 暂时没能接上，稍后再试试吧。');
    } finally {
      client.close(force: true);
    }
  }
}

class AiChatException implements Exception {
  const AiChatException(this.message);

  final String message;
}

class AiChatReply {
  const AiChatReply({
    required this.text,
    required this.process,
    required this.sources,
  });

  final String text;
  final String process;
  final List<AiChatSource> sources;
}

class AiChatProgress {
  const AiChatProgress({
    required this.text,
    required this.process,
    required this.sources,
  });

  final String text;
  final String process;
  final List<AiChatSource> sources;
}

class AiChatSource {
  const AiChatSource({required this.title, required this.url});

  final String title;
  final String url;
}

class AiContextLimitException extends AiChatException {
  const AiContextLimitException() : super('上下文已整理，正在重试。');
}

class AiQuotaException extends AiChatException {
  const AiQuotaException(super.message);
}

class AiChatMessage {
  const AiChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}
