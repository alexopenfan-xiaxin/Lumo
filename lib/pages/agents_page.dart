import 'dart:async';

import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../data.dart';
import '../widgets.dart';
import 'chat_page.dart';

class AgentsPage extends StatefulWidget {
  const AgentsPage({
    required this.companions,
    required this.catalogError,
    required this.onRetry,
    super.key,
  });

  final List<Companion> companions;
  final String? catalogError;
  final VoidCallback onRetry;

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  final _store = ChatStore();
  Map<String, _AgentPreview> _previews = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreviews());
  }

  @override
  void didUpdateWidget(AgentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companions != widget.companions) unawaited(_loadPreviews());
  }

  Future<void> _loadPreviews() async {
    final entries = await Future.wait(
      widget.companions.map((companion) async {
        final conversation = await _store.latestConversation(companion.id);
        if (conversation == null)
          return MapEntry(companion.id, const _AgentPreview());
        final messages = await _store.messages(conversation.id);
        return MapEntry(
          companion.id,
          _AgentPreview(
            text: messages.isEmpty ? conversation.title : messages.last.content,
            updatedAt: conversation.updatedAt,
          ),
        );
      }),
    );
    if (mounted)
      setState(
        () => _previews = Map<String, _AgentPreview>.fromEntries(entries),
      );
  }

  Future<void> _openChat(Companion companion, {bool createNew = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          companion: companion,
          heroTag: 'agents-${companion.id}',
          createNew: createNew,
        ),
      ),
    );
    await _loadPreviews();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('agents-scroll'),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          20,
          horizontalPadding,
          28,
        ),
        children: [
          const LumoPageTitle(title: '智能体', subtitle: '选择一位陪伴者延续对话'),
          if (widget.catalogError != null) ...[
            const SizedBox(height: 16),
            AgentCatalogNotice(
              message: widget.catalogError!,
              onRetry: widget.onRetry,
            ),
          ],
          const SizedBox(height: 28),
          if (widget.companions.isNotEmpty) ...[
            LumoSectionHeader(
              title: '我的陪伴',
              caption: '${widget.companions.length} 位陪伴者',
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < widget.companions.length;
                    index++
                  ) ...[
                    _AgentRow(
                      companion: widget.companions[index],
                      preview: _previews[widget.companions[index].id],
                      onTap: () => _openChat(widget.companions[index]),
                      onNewChat: () =>
                          _openChat(widget.companions[index], createNew: true),
                    ),
                    if (index != widget.companions.length - 1)
                      const Divider(height: 1, indent: 98, endIndent: 20),
                  ],
                ],
              ),
            ),
          ] else
            const _EmptyAgents(),
        ],
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({
    required this.companion,
    required this.preview,
    required this.onTap,
    required this.onNewChat,
  });

  final Companion companion;
  final _AgentPreview? preview;
  final VoidCallback onTap;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final available = companion.isAvailable;
    final text = preview?.text ?? companion.tagline;
    return InkWell(
      onTap: available ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Row(
          children: [
            CompanionAvatar(
              companion: companion,
              size: 64,
              heroTag: 'agents-${companion.id}',
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          companion.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        available ? '在线' : '未开放',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: available
                              ? Theme.of(context).colorScheme.secondary
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (preview?.updatedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _timeLabel(preview!.updatedAt!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: '与${companion.name}新建对话',
              onPressed: available ? onNewChat : null,
              icon: const Icon(Icons.add_comment_outlined, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}';
  }
}

class _EmptyAgents extends StatelessWidget {
  const _EmptyAgents();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 72),
    child: Column(
      children: [
        Icon(
          Icons.person_search_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 18),
        Text('暂无陪伴者', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('新的陪伴者正在准备中', style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _AgentPreview {
  const _AgentPreview({this.text, this.updatedAt});

  final String? text;
  final int? updatedAt;
}
