import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/ai_chat_client.dart';
import 'package:lumo/auth_client.dart';
import 'package:lumo/chat_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('turns a structurally invalid AI response into a chat error', () async {
    const channel = MethodChannel('app.lumo.companion/device');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(const <Object>[]));
      request.response.close();
    });

    final client = AiChatClient(
      endpoint: 'http://127.0.0.1:${server.port}/chat',
      authClient: AuthClient(
        store: ChatStore(factory: databaseFactoryFfi, databasePath: ':memory:'),
      ),
    );

    await expectLater(
      client.reply(
        const [AiChatMessage(role: 'user', content: '你好')],
        agentId: 'meow',
        summary: '',
        memories: const [],
      ),
      throwsA(isA<AiChatException>()),
    );
  });
}
