import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ai_chat_client.dart';
import '../chat_store.dart';
import '../context_window.dart';
import '../data.dart';
import '../speech_input.dart';
import '../widgets.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({required this.companion, required this.heroTag, super.key});

  final Companion companion;
  final String heroTag;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _aiChatClient = AiChatClient();
  final _speechInput = SpeechInput();
  late final ChatStore _store;
  late List<_ChatMessage> _messages = [
    _ChatMessage(
      id: 'opening',
      text: widget.companion.openingMessage,
      fromUser: false,
    ),
  ];
  Conversation? _conversation;
  List<MemoryEntry> _pendingMemories = const [];
  bool _isReplying = false;
  bool _isCompressing = false;
  String _streamedText = '';
  String? _drawingMessageId;
  String? _compressionStatus;
  bool _isLoadingConversation = false;
  bool _isListening = false;
  bool _isVoiceMode = false;
  int _contextUsage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.companion.isAvailable) {
      _store = ChatStore();
      unawaited(_loadConversation());
    }
  }

  @override
  void dispose() {
    unawaited(_speechInput.stop());
    unawaited(_speechInput.stopSpeaking());
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation({Conversation? conversation}) async {
    if (!widget.companion.isAvailable) return;
    setState(() => _isLoadingConversation = true);
    try {
      final selected =
          conversation ??
          await _store.latestConversation(widget.companion.id) ??
          await _store.createConversation(widget.companion.id);
      var storedMessages = await _store.messages(selected.id);
      if (storedMessages.isEmpty) {
        if (selected.summary.isEmpty) {
          await _store.addMessage(
            conversationId: selected.id,
            role: MessageRole.assistant,
            content: widget.companion.openingMessage,
          );
          storedMessages = await _store.messages(selected.id);
        }
      }
      final pending = await _store.memories(
        widget.companion.id,
        status: MemoryStatus.pending.name,
      );
      final approved = (await _store.memories(
        widget.companion.id,
        status: MemoryStatus.approved.name,
      )).take(100).toList();
      if (!mounted) return;
      setState(() {
        _conversation = selected;
        _messages = selected.summary.isNotEmpty && storedMessages.isEmpty
            ? const [
                _ChatMessage(
                  id: 'compressed-history',
                  text: '较早对话已压缩',
                  fromUser: false,
                ),
              ]
            : storedMessages.map(_ChatMessage.fromStored).toList();
        _compressionStatus =
            selected.summary.isNotEmpty && storedMessages.isEmpty
            ? '上下文压缩完成'
            : null;
        _pendingMemories = pending;
        _contextUsage = contextUsage(
          messages: storedMessages
              .where((message) => message.summarizedAt == null)
              .toList(),
          summary: selected.summary,
          memories: approved,
        );
      });
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _isLoadingConversation = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (MediaQuery.of(context).disableAnimations) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: 260.ms,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send([String? suggestedText]) async {
    final text = (suggestedText ?? _inputController.text).trim();
    if (text.isEmpty ||
        _isReplying ||
        _isCompressing ||
        _isLoadingConversation) {
      return;
    }
    if (!widget.companion.isAvailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该智能体暂未开放，敬请期待。')));
      return;
    }
    if (_conversation == null) {
      await _loadConversation();
    }
    final conversation = _conversation;
    if (conversation == null) return;

    HapticFeedback.lightImpact();
    final userMessage = await _store.addMessage(
      conversationId: conversation.id,
      role: MessageRole.user,
      content: text,
    );
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage.fromStored(userMessage));
      _inputController.clear();
      _isReplying = true;
      _streamedText = '';
      _drawingMessageId = null;
    });
    _scrollToEnd();

    try {
      var context = await _prepareContext(conversation.id);
      if (mounted) {
        setState(
          () => _contextUsage = contextUsage(
            messages: context.messages,
            summary: context.summary,
            memories: context.memories,
          ),
        );
      }
      AiChatReply reply;
      try {
        reply = await _aiChatClient.reply(
          context.messages.map(_asAiMessage).toList(),
          agentId: widget.companion.id,
          summary: context.summary,
          memories: context.memories.map((memory) => memory.content).toList(),
          onProgress: _updateStream,
        );
      } on AiContextLimitException {
        context = await _prepareContext(conversation.id, forceTrim: true);
        reply = await _aiChatClient.reply(
          context.messages.map(_asAiMessage).toList(),
          agentId: widget.companion.id,
          summary: context.summary,
          memories: context.memories.map((memory) => memory.content).toList(),
          onProgress: _updateStream,
        );
      }
      final image = reply.images.isEmpty
          ? const _CachedImage()
          : await _cacheImage(reply.images.first.url);
      final assistantMessage = await _store.addMessage(
        conversationId: conversation.id,
        role: MessageRole.assistant,
        content: reply.text,
        imageUrl: image.url,
        imagePath: image.path,
      );
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage.fromStored(assistantMessage));
          _contextUsage = contextUsage(
            messages: [...context.messages, assistantMessage],
            summary: context.summary,
            memories: context.memories,
          );
        });
        if (_isVoiceMode) unawaited(_speak(reply.text));
      }
      unawaited(_proposeMemories(conversation.id));
      unawaited(_compactContext(conversation.id));
    } on AiQuotaException catch (error) {
      await _store.deleteMessage(userMessage.id);
      if (mounted) {
        setState(
          () =>
              _messages.removeWhere((message) => message.id == userMessage.id),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on AiChatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本地会话保存失败，请稍后再试。')));
      }
    } finally {
      if (mounted) {
        setState(() => _isReplying = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _updateStream(AiChatProgress progress) async {
    if (progress.drawingText case final text? when _drawingMessageId == null) {
      final conversation = _conversation;
      if (conversation != null) {
        final message = await _store.addMessage(
          conversationId: conversation.id,
          role: MessageRole.assistant,
          content: text,
        );
        _drawingMessageId = message.id;
        if (mounted) {
          setState(() => _messages.add(_ChatMessage.fromStored(message)));
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _streamedText = progress.text;
    });
    _scrollToEnd();
  }

  Future<_CachedImage> _cacheImage(String url) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != HttpStatus.ok) return _CachedImage(url: url);
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytes.add(chunk);
        if (bytes.length > 12 * 1024 * 1024) {
          return _CachedImage(url: url);
        }
      }
      final data = bytes.takeBytes();
      final imageType = _imageType(data);
      if (imageType == null) return _CachedImage(url: url);
      try {
        final path = await _store.cacheImage(data, imageType.extension);
        return _CachedImage(url: url, path: path);
      } on FileSystemException {
        return _CachedImage(url: url);
      }
    } catch (_) {
      return _CachedImage(url: url);
    } finally {
      client.close(force: true);
    }
  }

  _ImageType? _imageType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return const _ImageType('png');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return const _ImageType('jpg');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return const _ImageType('webp');
    }
    return null;
  }

  Future<_PreparedContext> _prepareContext(
    String conversationId, {
    bool forceTrim = false,
  }) async {
    final existingConversation = await _store.conversation(conversationId);
    if (existingConversation == null) throw const AiChatException('当前会话已不存在。');
    final messages = (await _store.messages(
      existingConversation.id,
    )).where((message) => message.summarizedAt == null).toList();
    final memories = (await _store.memories(
      widget.companion.id,
      status: MemoryStatus.approved.name,
    )).take(100).toList();
    final window = limitContext(
      messages: messages,
      summary: existingConversation.summary,
      memories: memories,
    );
    final contextMessages = forceTrim && window.messages.length > 1
        ? window.messages.skip(1).toList()
        : window.messages;
    if (contextMessages.isEmpty) {
      throw const AiChatException('上下文内容过大，无法继续整理。');
    }
    return _PreparedContext(
      messages: contextMessages,
      summary: existingConversation.summary,
      memories: memories,
    );
  }

  Future<void> _compactContext(String conversationId) async {
    final conversation = await _store.conversation(conversationId);
    if (conversation == null) return;
    final messages = (await _store.messages(
      conversationId,
    )).where((message) => message.summarizedAt == null).toList();
    final memories = (await _store.memories(
      widget.companion.id,
      status: MemoryStatus.approved.name,
    )).take(100).toList();
    final window = limitContext(
      messages: messages,
      summary: conversation.summary,
      memories: memories,
    );
    if (window.removedMessageIds.isEmpty) return;
    final ids = window.removedMessageIds.toSet();
    final batch = _summaryBatch(
      messages.where((message) => ids.contains(message.id)).toList(),
    );
    if (batch.isEmpty) return;
    if (mounted && _conversation?.id == conversationId) {
      setState(() {
        _isCompressing = true;
        _compressionStatus = '上下文压缩中';
      });
    }
    try {
      final summary = await _aiChatClient.summarize(
        conversation.summary,
        batch.map(_asAiMessage).toList(),
        agentId: widget.companion.id,
      );
      await _store.replaceSummaryAndMarkMessages(
        conversationId: conversationId,
        summary: summary,
        messageIds: batch.map((message) => message.id).toList(),
      );
    } on AiChatException {
      return;
    } finally {
      if (mounted && _conversation?.id == conversationId) {
        setState(() {
          _isCompressing = false;
          _compressionStatus = '上下文压缩完成';
        });
      }
    }
  }

  List<StoredMessage> _summaryBatch(List<StoredMessage> messages) {
    final batch = <StoredMessage>[];
    var tokens = 0;
    for (final message in messages) {
      final messageTokens = estimatedTokens(message.content);
      if (batch.isNotEmpty && tokens + messageTokens > 24000) break;
      batch.add(message);
      tokens += messageTokens;
    }
    return batch;
  }

  Future<void> _proposeMemories(String conversationId) async {
    try {
      final messages = await _store.messages(conversationId);
      if (messages.length < 2) return;
      final approved = await _store.memories(
        widget.companion.id,
        status: MemoryStatus.approved.name,
      );
      final candidates = await _aiChatClient.memoryCandidates(
        messages.skip(messages.length - 2).map(_asAiMessage).toList(),
        approved.take(100).map((memory) => memory.content).toList(),
        agentId: widget.companion.id,
      );
      if (candidates.isEmpty) return;
      await _store.addMemoryCandidates(widget.companion.id, candidates);
      final pending = await _store.memories(
        widget.companion.id,
        status: MemoryStatus.pending.name,
      );
      if (mounted) setState(() => _pendingMemories = pending);
    } on Exception {
      // Memory suggestions are optional; a chat reply must not be affected by their failure.
    }
  }

  AiChatMessage _asAiMessage(StoredMessage message) => AiChatMessage(
    role: message.role == MessageRole.user ? 'user' : 'assistant',
    content: message.content,
  );

  Future<void> _showSessions() async {
    Future<List<Conversation>> sessions = _store.conversations(
      widget.companion.id,
    );
    final selected = await showModalBottomSheet<Conversation>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: FutureBuilder<List<Conversation>>(
            future: sessions,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Conversation>[];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '会话',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            final conversation = await _store
                                .createConversation(widget.companion.id);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext, conversation);
                            }
                          },
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('新建'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final conversation = items[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                conversation.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _timeLabel(conversation.updatedAt),
                              ),
                              onTap: () =>
                                  Navigator.pop(sheetContext, conversation),
                              trailing: IconButton(
                                tooltip: '删除会话',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async {
                                  await _store.deleteConversation(
                                    conversation.id,
                                  );
                                  setSheetState(
                                    () => sessions = _store.conversations(
                                      widget.companion.id,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null) await _loadConversation(conversation: selected);
  }

  Future<void> _showMemories() async {
    Future<List<MemoryEntry>> memoryFuture = _store.memories(
      widget.companion.id,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: FutureBuilder<List<MemoryEntry>>(
                future: memoryFuture,
                builder: (context, snapshot) {
                  final memories = snapshot.data ?? const <MemoryEntry>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.companion.name}的记忆',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: '清空全部记忆',
                            onPressed: memories.isEmpty
                                ? null
                                : () async {
                                    if (!await _confirm(
                                      '清空全部记忆？',
                                      '已确认和待确认的记忆都会永久删除。',
                                    )) {
                                      return;
                                    }
                                    await _store.clearMemories(
                                      widget.companion.id,
                                    );
                                    setSheetState(
                                      () => memoryFuture = _store.memories(
                                        widget.companion.id,
                                      ),
                                    );
                                    if (mounted) {
                                      setState(
                                        () => _pendingMemories = const [],
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.delete_sweep_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '只有确认后的内容会在后续对话中使用。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: memories.length,
                          separatorBuilder: (_, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final memory = memories[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(memory.content),
                              subtitle: Text(_memoryLabel(memory.status)),
                              trailing: Wrap(
                                spacing: 2,
                                children: [
                                  if (memory.status == MemoryStatus.pending)
                                    IconButton(
                                      tooltip: '确认记忆',
                                      onPressed: () async {
                                        await _store.updateMemory(
                                          memory.copyWith(
                                            status: MemoryStatus.approved,
                                          ),
                                        );
                                        setSheetState(
                                          () => memoryFuture = _store.memories(
                                            widget.companion.id,
                                          ),
                                        );
                                        _refreshPendingMemories();
                                      },
                                      icon: const Icon(Icons.check_rounded),
                                    ),
                                  IconButton(
                                    tooltip: '编辑记忆',
                                    onPressed: () async {
                                      final edited = await _editMemory(
                                        memory.content,
                                      );
                                      if (edited == null) return;
                                      await _store.updateMemory(
                                        memory.copyWith(content: edited),
                                      );
                                      setSheetState(
                                        () => memoryFuture = _store.memories(
                                          widget.companion.id,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '删除记忆',
                                    onPressed: () async {
                                      await _store.deleteMemory(memory.id);
                                      setSheetState(
                                        () => memoryFuture = _store.memories(
                                          widget.companion.id,
                                        ),
                                      );
                                      _refreshPendingMemories();
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshPendingMemories() async {
    final pending = await _store.memories(
      widget.companion.id,
      status: MemoryStatus.pending.name,
    );
    if (mounted) setState(() => _pendingMemories = pending);
  }

  Future<void> _beginSpeech() async {
    if (_isListening) return;
    setState(() => _isListening = true);
    try {
      final text = await _speechInput.start();
      if (text.isNotEmpty && mounted) {
        _inputController.text = text;
        _inputController.selection = TextSelection.collapsed(
          offset: text.length,
        );
        setState(() {});
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message ?? '无法启动语音输入。')));
      }
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _endSpeech() => unawaited(_speechInput.stop());

  Future<void> _speak(String text) async {
    try {
      await _speechInput.speak(text);
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message ?? '无法播放语音回复。')));
      }
    }
  }

  String _timeLabel(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('清空'),
            ),
          ],
        ),
      ) ??
      false;

  Future<String?> _editMemory(String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑记忆'),
        content: TextField(
          controller: controller,
          maxLength: 240,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.isEmpty ?? true ? null : result;
  }

  String _memoryLabel(MemoryStatus status) => switch (status) {
    MemoryStatus.pending => '等待你的确认',
    MemoryStatus.approved => '已用于后续对话',
    MemoryStatus.rejected => '已拒绝',
  };

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = lumoHorizontalPadding(context);
    final messageDuration = lumoMotionDuration(context, 220);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CompanionAvatar(
              companion: widget.companion,
              size: 42,
              heroTag: widget.heroTag,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.companion.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.companion.isAvailable)
            Tooltip(
              message:
                  '上下文已使用 ${(_contextUsage / maxDynamicContextTokens * 100).round()}%',
              child: Semantics(
                label:
                    '上下文已使用 ${(_contextUsage / maxDynamicContextTokens * 100).round()}%',
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        value: (_contextUsage / maxDynamicContextTokens)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        strokeWidth: 2.5,
                        backgroundColor: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.companion.isAvailable)
            IconButton(
              tooltip: '会话管理',
              onPressed: _showSessions,
              icon: const Icon(Icons.forum_outlined),
            ),
          if (widget.companion.isAvailable)
            IconButton(
              tooltip: '${widget.companion.name}的记忆',
              onPressed: _showMemories,
              icon: const Icon(Icons.psychology_outlined),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _isLoadingConversation
                  ? Center(
                      child: Semantics(
                        label: '正在载入会话',
                        liveRegion: true,
                        child: const CircularProgressIndicator(),
                      ),
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        20,
                        horizontalPadding,
                        20,
                      ),
                      children: [
                        for (final message in _messages)
                          _MessageBubble(message: message)
                              .animate(key: ValueKey(message.id))
                              .fadeIn(duration: messageDuration)
                              .slideY(
                                begin: 0.035,
                                end: 0,
                                duration: messageDuration,
                              ),
                        if (_compressionStatus case final status?)
                          _CompressionNotice(text: status),
                        if (_isReplying)
                          _streamedText.isEmpty
                              ? _TypingBubble(color: widget.companion.color)
                              : _MessageBubble(
                                  message: _ChatMessage(
                                    id: 'streaming',
                                    text: _streamedText,
                                    fromUser: false,
                                  ),
                                ),
                      ],
                    ),
            ),
            if (_pendingMemories.isNotEmpty)
              Semantics(
                button: true,
                label: '有 ${_pendingMemories.length} 条记忆等待确认',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.psychology_outlined),
                      title: Text(
                        '${widget.companion.name}想记住 ${_pendingMemories.length} 件事',
                      ),
                      subtitle: const Text('确认后才会用于后续对话'),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                      ),
                      onTap: _showMemories,
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding - 8,
                  10,
                  horizontalPadding - 8,
                  12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: _isVoiceMode ? '切换到文字输入' : '切换到语音输入',
                      onPressed: _isReplying
                          ? null
                          : () {
                              if (_isListening) _endSpeech();
                              setState(() => _isVoiceMode = !_isVoiceMode);
                            },
                      icon: Icon(
                        _isVoiceMode
                            ? Icons.keyboard_outlined
                            : Icons.mic_none_rounded,
                      ),
                    ),
                    Expanded(
                      child: _isVoiceMode
                          ? Semantics(
                              button: true,
                              label: _isListening ? '松开结束语音输入' : '按住说话',
                              child: GestureDetector(
                                onLongPressStart: (_) =>
                                    unawaited(_beginSpeech()),
                                onLongPressEnd: (_) => _endSpeech(),
                                onLongPressCancel: _endSpeech,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _isListening
                                        ? Theme.of(context).colorScheme.primary
                                              .withValues(alpha: 0.16)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _isListening
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: Text(
                                    _isListening ? '松开 结束语音输入' : '按住 说话',
                                  ),
                                ),
                              ),
                            )
                          : Semantics(
                              label: '消息输入框',
                              textField: true,
                              child: TextField(
                                controller: _inputController,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 4000,
                                textInputAction: TextInputAction.send,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: _send,
                                decoration: const InputDecoration(
                                  hintText: '说说此刻的感受…',
                                  counterText: '',
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '发送',
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed:
                              _isReplying ||
                                  _isCompressing ||
                                  _isLoadingConversation ||
                                  _inputController.text.trim().isEmpty
                              ? null
                              : _send,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('发送'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreparedContext {
  const _PreparedContext({
    required this.messages,
    required this.summary,
    required this.memories,
  });

  final List<StoredMessage> messages;
  final String summary;
  final List<MemoryEntry> memories;
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.text,
    required this.fromUser,
    this.process = '',
    this.sources = const [],
    this.imageData = '',
    this.imageUrl = '',
    this.imagePath = '',
    this.summarizedAt,
  });

  final String id;
  final String text;
  final bool fromUser;
  final String process;
  final List<MessageSource> sources;
  final String imageData;
  final String imageUrl;
  final String imagePath;
  final int? summarizedAt;

  factory _ChatMessage.fromStored(StoredMessage message) => _ChatMessage(
    id: message.id,
    text: message.content,
    fromUser: message.role == MessageRole.user,
    process: message.process,
    sources: message.sources,
    imageData: message.imageData,
    imageUrl: message.imageUrl,
    imagePath: message.imagePath,
    summarizedAt: message.summarizedAt,
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) => Align(
    alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width * 0.78)
            .clamp(240.0, 420.0)
            .toDouble(),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: message.fromUser
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(message.fromUser ? 18 : 5),
          bottomRight: Radius.circular(message.fromUser ? 5 : 18),
        ),
        border: message.fromUser
            ? null
            : Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.text.isNotEmpty)
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: message.fromUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
            ),
          if (message.imagePath.isNotEmpty) ...[
            if (message.text.isNotEmpty) const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(message.imagePath),
                fit: BoxFit.cover,
                semanticLabel: '智能体生成的图片',
                errorBuilder: (_, _, _) => message.imageUrl.isEmpty
                    ? const SizedBox.shrink()
                    : Image.network(
                        message.imageUrl,
                        fit: BoxFit.cover,
                        semanticLabel: '智能体生成的图片',
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
            ),
          ] else if (message.imageData.isNotEmpty) ...[
            if (message.text.isNotEmpty) const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(message.imageData.split(',').last),
                fit: BoxFit.cover,
                semanticLabel: '智能体生成的图片',
              ),
            ),
          ] else if (message.imageUrl.isNotEmpty) ...[
            if (message.text.isNotEmpty) const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                message.imageUrl,
                fit: BoxFit.cover,
                semanticLabel: '智能体生成的图片',
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('图片链接已失效'),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CompressionNotice extends StatelessWidget {
  const _CompressionNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.compress_rounded, size: 16),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _CachedImage {
  const _CachedImage({this.url = '', this.path = ''});

  final String url;
  final String path;
}

class _ImageType {
  const _ImageType(this.extension);

  final String extension;
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Semantics(
      label: '智能体正在回复',
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              child: LinearProgressIndicator(
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(width: 12),
            const Text('正在回复…'),
          ],
        ),
      ),
    ),
  );
}
