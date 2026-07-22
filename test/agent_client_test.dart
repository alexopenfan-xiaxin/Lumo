import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/agent_client.dart';

void main() {
  test('loads public agent metadata from the shared Pages endpoint', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      expect(request.uri.path, '/agents');
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'agents': [
              {
                'id': 'new_agent',
                'name': '新伙伴',
                'glyph': '新',
                'tagline': '陪你好好说话',
                'color': '#A45F41',
                'people': '陪伴者',
                'lastMessage': '最近消息',
                'openingMessage': '你好',
                'avatarUrl': 'https://example.com/avatar.jpg',
                'enabled': true,
                'sortOrder': 0,
              },
            ],
          }),
        );
      request.response.close();
    });

    final agents = await AgentClient(
      endpoint: 'http://127.0.0.1:${server.port}/chat',
    ).fetchAgents();

    expect(agents.single.id, 'new_agent');
    expect(agents.single.avatarUrl, 'https://example.com/avatar.jpg');
  });

  test('reports malformed public agent metadata as a catalog error', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'agents': [
              {'id': 'broken', 'color': null},
            ],
          }),
        );
      request.response.close();
    });

    await expectLater(
      AgentClient(
        endpoint: 'http://127.0.0.1:${server.port}/chat',
      ).fetchAgents(),
      throwsA(isA<AgentCatalogException>()),
    );
  });
}
