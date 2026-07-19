import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/chat_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'stores a conversation and deletes compressed source messages',
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
        sources: const [MessageSource(title: '示例来源', url: 'https://example.com')],
      );

      await store.replaceSummaryAndDeleteMessages(
        conversationId: conversation.id,
        summary: '用户喜欢在安静的时候散步。',
        messageIds: [first.id],
      );

      final messages = await store.messages(conversation.id);
      final saved = await store.conversation(conversation.id);
      expect(messages, hasLength(1));
      expect(saved?.summary, '用户喜欢在安静的时候散步。');
      expect(messages.single.process, '已结合对话上下文生成回复');
      expect(messages.single.sources.single.url, 'https://example.com');
    },
  );

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
