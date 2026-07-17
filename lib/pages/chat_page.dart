import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ai_chat_client.dart';
import '../data.dart';
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
  late final List<_ChatMessage> _messages = [
    _ChatMessage(text: widget.companion.openingMessage, fromUser: false),
  ];
  bool _isReplying = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    if (text.isEmpty || _isReplying) return;
    if (!widget.companion.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该智能体暂未开放，敬请期待。')));
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _inputController.clear();
      _isReplying = true;
    });
    _scrollToEnd();
    try {
      final reply = await _aiChatClient.reply(
        _messages
            .map((message) => AiChatMessage(role: message.fromUser ? 'user' : 'assistant', content: message.text))
            .toList(),
      );
      if (mounted) {
        setState(() => _messages.add(_ChatMessage(text: reply, fromUser: false)));
      }
    } on AiChatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isReplying = false;
        });
        _scrollToEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          CompanionAvatar(companion: widget.companion, size: 42, heroTag: widget.heroTag),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.companion.name, style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(widget.companion.isAvailable ? '此刻在线' : '暂未开放', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: '对话信息',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(widget.companion.name),
              content: Text('${widget.companion.tagline}\n\n演示对话仅保存在当前会话中。'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
            ),
          ),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            // ponytail: eager children fit the short local demo; use a builder when histories are persisted.
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                for (final message in _messages)
                  _MessageBubble(message: message, color: widget.companion.color)
                      .animate(key: ValueKey(message))
                      .fadeIn(duration: MediaQuery.of(context).disableAnimations ? Duration.zero : 220.ms)
                      .slideY(begin: 0.04, end: 0),
                if (_isReplying) _TypingBubble(color: widget.companion.color),
              ],
            ),
          ),
          if (_messages.length == 1 && widget.companion.isAvailable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  for (final prompt in const ['今天有点累', '想做一次呼吸练习', '只是想找人说说话']) ...[
                    ActionChip(label: Text(prompt), onPressed: () => _send(prompt)),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '语音输入',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('语音演示：长按后即可说话')),
                    ),
                    icon: const Icon(Icons.mic_none_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _send,
                      decoration: const InputDecoration(hintText: '说说此刻的感受…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '发送',
                    onPressed: _isReplying || _inputController.text.trim().isEmpty ? null : _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
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

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.color});

  final _ChatMessage message;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 310),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: message.fromUser ? color : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(message.fromUser ? 18 : 5),
          bottomRight: Radius.circular(message.fromUser ? 5 : 18),
        ),
        border: message.fromUser ? null : Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        message.text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: message.fromUser ? Colors.white : null,
        ),
      ),
    ),
  );
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Semantics(
      label: '陪伴者正在回复',
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: SizedBox(
          width: 36,
          child: LinearProgressIndicator(
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ),
    ),
  );
}
