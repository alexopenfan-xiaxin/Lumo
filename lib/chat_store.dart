import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class ChatStore {
  ChatStore({DatabaseFactory? factory, String? databasePath})
      : _factory = factory ?? databaseFactory,
        _databasePath = databasePath;

  final DatabaseFactory _factory;
  final String? _databasePath;
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final path = _databasePath ?? join(await getDatabasesPath(), 'lumo_chat.db');
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE conversations (
              id TEXT PRIMARY KEY,
              agent_id TEXT NOT NULL,
              title TEXT NOT NULL,
              summary TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE messages (
              id TEXT PRIMARY KEY,
              conversation_id TEXT NOT NULL,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await database.execute('CREATE INDEX messages_conversation_time ON messages(conversation_id, created_at)');
          await database.execute('''
            CREATE TABLE memories (
              id TEXT PRIMARY KEY,
              agent_id TEXT NOT NULL,
              content TEXT NOT NULL,
              status TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await database.execute('CREATE INDEX memories_agent_status ON memories(agent_id, status)');
        },
      ),
    );
    return _database!;
  }

  Future<List<Conversation>> conversations(String agentId) async {
    final rows = await (await _db).query(
      'conversations',
      where: 'agent_id = ?',
      whereArgs: [agentId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Conversation.fromRow).toList();
  }

  Future<Conversation?> latestConversation(String agentId) async {
    final rows = await (await _db).query(
      'conversations',
      where: 'agent_id = ?',
      whereArgs: [agentId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Conversation.fromRow(rows.first);
  }

  Future<Conversation?> conversation(String conversationId) async {
    final rows = await (await _db).query('conversations', where: 'id = ?', whereArgs: [conversationId], limit: 1);
    return rows.isEmpty ? null : Conversation.fromRow(rows.first);
  }

  Future<Conversation> createConversation(String agentId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final conversation = Conversation(
      id: _id('conversation'),
      agentId: agentId,
      title: '新的对话',
      summary: '',
      createdAt: now,
      updatedAt: now,
    );
    await (await _db).insert('conversations', conversation.toRow());
    return conversation;
  }

  Future<List<StoredMessage>> messages(String conversationId) async {
    final rows = await (await _db).query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map(StoredMessage.fromRow).toList();
  }

  Future<StoredMessage> addMessage({
    required String conversationId,
    required MessageRole role,
    required String content,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final message = StoredMessage(
      id: _id('message'),
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: now,
    );
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.insert('messages', message.toRow());
      await transaction.update('conversations', {'updated_at': now}, where: 'id = ?', whereArgs: [conversationId]);
      if (role == MessageRole.user) {
        final conversation = await transaction.query('conversations', columns: ['title'], where: 'id = ?', whereArgs: [conversationId]);
        if (conversation.single['title'] == '新的对话') {
          await transaction.update('conversations', {'title': _title(content)}, where: 'id = ?', whereArgs: [conversationId]);
        }
      }
    });
    return message;
  }

  Future<void> replaceSummaryAndDeleteMessages({
    required String conversationId,
    required String summary,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.update(
        'conversations',
        {'summary': summary, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
      final marks = List.filled(messageIds.length, '?').join(',');
      await transaction.delete('messages', where: 'id IN ($marks)', whereArgs: messageIds);
    });
  }

  Future<void> deleteConversation(String conversationId) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.delete('messages', where: 'conversation_id = ?', whereArgs: [conversationId]);
      await transaction.delete('conversations', where: 'id = ?', whereArgs: [conversationId]);
    });
  }

  Future<void> clearConversations(String agentId) async {
    final rows = await conversations(agentId);
    for (final conversation in rows) {
      await deleteConversation(conversation.id);
    }
  }

  Future<List<MemoryEntry>> memories(String agentId, {String? status}) async {
    final rows = await (await _db).query(
      'memories',
      where: status == null ? 'agent_id = ?' : 'agent_id = ? AND status = ?',
      whereArgs: status == null ? [agentId] : [agentId, status],
      orderBy: 'created_at DESC',
    );
    return rows.map(MemoryEntry.fromRow).toList();
  }

  Future<void> addMemoryCandidates(String agentId, List<String> candidates) async {
    final database = await _db;
    final existing = await memories(agentId);
    final existingTexts = existing.map((memory) => memory.content).toSet();
    for (final content in candidates.map((candidate) => candidate.trim()).where((candidate) => candidate.isNotEmpty)) {
      final conciseContent = content.length > 240 ? content.substring(0, 240) : content;
      if (existingTexts.contains(conciseContent)) continue;
      await database.insert(
        'memories',
        MemoryEntry(
          id: _id('memory'),
          agentId: agentId,
          content: conciseContent,
          status: MemoryStatus.pending,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ).toRow(),
      );
      existingTexts.add(conciseContent);
    }
  }

  Future<void> updateMemory(MemoryEntry memory) async {
    await (await _db).update('memories', memory.toRow(), where: 'id = ?', whereArgs: [memory.id]);
  }

  Future<void> deleteMemory(String memoryId) async => (await _db).delete('memories', where: 'id = ?', whereArgs: [memoryId]);

  Future<void> clearMemories(String agentId) async =>
      (await _db).delete('memories', where: 'agent_id = ?', whereArgs: [agentId]);

  String _id(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().hashCode}';

  String _title(String content) => content.length > 18 ? '${content.substring(0, 18)}…' : content;
}

enum MessageRole { user, assistant }

class Conversation {
  const Conversation({
    required this.id,
    required this.agentId,
    required this.title,
    required this.summary,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String agentId;
  final String title;
  final String summary;
  final int createdAt;
  final int updatedAt;

  factory Conversation.fromRow(Map<String, Object?> row) => Conversation(
        id: row['id']! as String,
        agentId: row['agent_id']! as String,
        title: row['title']! as String,
        summary: row['summary']! as String,
        createdAt: row['created_at']! as int,
        updatedAt: row['updated_at']! as int,
      );

  Conversation copyWith({String? title, String? summary}) => Conversation(
        id: id,
        agentId: agentId,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'agent_id': agentId,
        'title': title,
        'summary': summary,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class StoredMessage {
  const StoredMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final int createdAt;

  factory StoredMessage.fromRow(Map<String, Object?> row) => StoredMessage(
        id: row['id']! as String,
        conversationId: row['conversation_id']! as String,
        role: row['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
        content: row['content']! as String,
        createdAt: row['created_at']! as int,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role.name,
        'content': content,
        'created_at': createdAt,
      };
}

enum MemoryStatus { pending, approved, rejected }

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.agentId,
    required this.content,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String agentId;
  final String content;
  final MemoryStatus status;
  final int createdAt;

  factory MemoryEntry.fromRow(Map<String, Object?> row) => MemoryEntry(
        id: row['id']! as String,
        agentId: row['agent_id']! as String,
        content: row['content']! as String,
        status: MemoryStatus.values.byName(row['status']! as String),
        createdAt: row['created_at']! as int,
      );

  MemoryEntry copyWith({String? content, MemoryStatus? status}) => MemoryEntry(
        id: id,
        agentId: agentId,
        content: content ?? this.content,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'agent_id': agentId,
        'content': content,
        'status': status.name,
        'created_at': createdAt,
      };
}
