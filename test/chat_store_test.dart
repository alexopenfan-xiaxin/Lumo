import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/chat_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'stores a conversation and keeps compressed source messages visible',
    () async {
      final store = ChatStore(
        factory: databaseFactoryFfi,
        databasePath: ':memory:',
      );
      final conversation = await store.createConversation('meow');
      final first = await store.addMessage(
        conversationId: conversation.id,
        role: MessageRole.user,
        content: '我喜欢在安静的时候散步。',
      );
      await store.addMessage(
        conversationId: conversation.id,
        role: MessageRole.assistant,
        content: '我记住啦，散步听起来很舒服。',
        process: '已结合对话上下文生成回复',
        imageData: 'data:image/png;base64,AA==',
        imageUrl: 'https://example.com/image.png',
        imagePath:
            '/data/user/0/app.lumo.companion/databases/lumo_images/image.png',
        sources: const [
          MessageSource(title: '示例来源', url: 'https://example.com'),
        ],
      );

      await store.replaceSummaryAndMarkMessages(
        conversationId: conversation.id,
        summary: '用户喜欢在安静的时候散步。',
        messageIds: [first.id],
      );

      final messages = await store.messages(conversation.id);
      final saved = await store.conversation(conversation.id);
      expect(messages, hasLength(2));
      expect(saved?.summary, '用户喜欢在安静的时候散步。');
      expect(messages.first.summarizedAt, isNotNull);
      expect(messages.last.process, '已结合对话上下文生成回复');
      expect(messages.last.sources.single.url, 'https://example.com');
      expect(messages.last.imageData, 'data:image/png;base64,AA==');
      expect(messages.last.imageUrl, 'https://example.com/image.png');
      expect(
        messages.last.imagePath,
        '/data/user/0/app.lumo.companion/databases/lumo_images/image.png',
      );
    },
  );

  test(
    'retains visible messages when every source message is compressed',
    () async {
      final store = ChatStore(
        factory: databaseFactoryFfi,
        databasePath: ':memory:',
      );
      final conversation = await store.createConversation('meow');
      final message = await store.addMessage(
        conversationId: conversation.id,
        role: MessageRole.user,
        content: '一段较早的对话。',
      );

      await store.replaceSummaryAndMarkMessages(
        conversationId: conversation.id,
        summary: '已压缩的对话摘要。',
        messageIds: [message.id],
      );

      final messages = await store.messages(conversation.id);
      expect(messages.single.summarizedAt, isNotNull);
      expect((await store.conversation(conversation.id))?.summary, '已压缩的对话摘要。');
    },
  );

  test('keeps message writes scoped to their conversation', () async {
    final store = ChatStore(
      factory: databaseFactoryFfi,
      databasePath: ':memory:',
    );
    final firstConversation = await store.createConversation('meow');
    final secondConversation = await store.createConversation('meow');
    final first = await store.addMessage(
      conversationId: firstConversation.id,
      role: MessageRole.user,
      content: '第一段会话',
    );
    final second = await store.addMessage(
      conversationId: secondConversation.id,
      role: MessageRole.user,
      content: '第二段会话',
    );

    await store.replaceSummaryAndMarkMessages(
      conversationId: firstConversation.id,
      summary: '第一段摘要',
      messageIds: [first.id, second.id],
    );

    expect(
      (await store.messages(firstConversation.id)).single.summarizedAt,
      isNotNull,
    );
    expect(
      (await store.messages(secondConversation.id)).single.summarizedAt,
      isNull,
    );
    await expectLater(
      store.addMessage(
        conversationId: 'missing-conversation',
        role: MessageRole.assistant,
        content: '不应落库',
      ),
      throwsStateError,
    );
    expect(await store.messages('missing-conversation'), isEmpty);

    final otherAgent = await store.createConversation('kun');
    await store.addMessage(
      conversationId: otherAgent.id,
      role: MessageRole.assistant,
      content: '保留的会话',
    );
    await store.clearConversations('meow');
    expect(await store.conversations('meow'), isEmpty);
    expect(await store.messages(firstConversation.id), isEmpty);
    expect(await store.messages(secondConversation.id), isEmpty);
    expect(await store.messages(otherAgent.id), hasLength(1));
  });

  test('keeps memory candidates pending until approved', () async {
    final store = ChatStore(
      factory: databaseFactoryFfi,
      databasePath: ':memory:',
    );
    await store.addMemoryCandidates('meow', ['用户偏好简短的晚间聊天。']);
    final pending = await store.memories(
      'meow',
      status: MemoryStatus.pending.name,
    );
    expect(pending, hasLength(1));

    await store.updateMemory(
      pending.single.copyWith(status: MemoryStatus.approved),
    );
    expect(
      await store.memories('meow', status: MemoryStatus.pending.name),
      isEmpty,
    );
    expect(
      await store.memories('meow', status: MemoryStatus.approved.name),
      hasLength(1),
    );
  });
}
