import 'dart:convert';

import 'chat_store.dart';

const maxDynamicContextTokens = 128000;

class ContextWindow {
  const ContextWindow({required this.messages, required this.removedMessageIds});

  final List<StoredMessage> messages;
  final List<String> removedMessageIds;
}

int estimatedTokens(String value) => utf8.encode(value).length;

ContextWindow limitContext({
  required List<StoredMessage> messages,
  required String summary,
  required List<MemoryEntry> memories,
}) {
  var usedTokens = estimatedTokens(summary);
  for (final memory in memories) {
    usedTokens += estimatedTokens(memory.content);
  }

  final kept = <StoredMessage>[];
  final removed = <String>[];
  for (final message in messages.reversed) {
    final messageTokens = estimatedTokens(message.content);
    if (usedTokens + messageTokens > maxDynamicContextTokens) {
      removed.add(message.id);
    } else {
      kept.add(message);
      usedTokens += messageTokens;
    }
  }
  return ContextWindow(messages: kept.reversed.toList(), removedMessageIds: removed.reversed.toList());
}
