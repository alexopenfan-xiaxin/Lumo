import 'package:flutter_test/flutter_test.dart';
import 'package:lumo/chat_store.dart';
import 'package:lumo/context_window.dart';

StoredMessage message(String id, String content) => StoredMessage(
  id: id,
  conversationId: 'conversation',
  role: MessageRole.user,
  content: content,
  createdAt: 0,
);

void main() {
  test('reports UTF-8 context usage across every dynamic source', () {
    expect(
      contextUsage(
        messages: [message('message', '你好')],
        summary: 'abc',
        memories: const [
          MemoryEntry(
            id: 'memory',
            agentId: 'meow',
            content: '记忆',
            status: MemoryStatus.approved,
            createdAt: 0,
          ),
        ],
      ),
      15,
    );
  });

  test('removes oldest messages before recent messages at the 128k budget', () {
    final oldest = message('oldest', List.filled(70000, 'a').join());
    final newest = message('newest', List.filled(70000, 'b').join());

    final window = limitContext(
      messages: [oldest, newest],
      summary: '',
      memories: const [],
    );

    expect(window.removedMessageIds, ['oldest']);
    expect(window.messages.map((item) => item.id), ['newest']);
  });

  test('counts summaries and approved memories inside the dynamic budget', () {
    final window = limitContext(
      messages: [message('message', List.filled(127000, 'a').join())],
      summary: List.filled(800, 's').join(),
      memories: [
        MemoryEntry(
          id: 'memory',
          agentId: 'meow',
          content: List.filled(800, 'm').join(),
          status: MemoryStatus.approved,
          createdAt: 0,
        ),
      ],
    );

    expect(window.removedMessageIds, ['message']);
  });
}
