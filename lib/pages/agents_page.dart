import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data.dart';
import '../widgets.dart';
import 'chat_page.dart';

class AgentsPage extends StatefulWidget {
  const AgentsPage({super.key});

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(Companion companion) {
    final heroTag = 'agents-${companion.id}';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(companion: companion, heroTag: heroTag),
      ),
    );
  }

  void _showNewConversation() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择一位陪伴者', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final companion in companions.take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CompanionAvatar(companion: companion, size: 44),
                  title: Text(companion.name),
                  subtitle: Text(companion.tagline, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openChat(companion);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = companions.where((companion) {
      final searchText = '${companion.name}${companion.tagline}${companion.lastMessage}';
      return searchText.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion ? Duration.zero : 260.ms;
    final horizontalPadding = lumoHorizontalPadding(context);

    return SafeArea(
      child: CustomScrollView(
        key: const PageStorageKey('agents-scroll'),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  LumoPageTitle(
                    title: '智能体',
                    subtitle: '延续一段熟悉的对话',
                    trailing: IconButton.filledTonal(
                      tooltip: '新建对话',
                      onPressed: _showNewConversation,
                      icon: const Icon(Icons.add_comment_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SearchBar(
                    controller: _searchController,
                    hintText: '搜索对话或陪伴者',
                    leading: const Icon(Icons.search_rounded),
                    trailing: [
                      if (_query.isNotEmpty)
                        IconButton(
                          tooltip: '清空搜索',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptySearch(),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 28),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _ConversationCard(
                  companion: filtered[index],
                  heroTag: 'agents-${filtered[index].id}',
                  onTap: () => _openChat(filtered[index]),
                )
                    .animate()
                    .fadeIn(
                      delay: reduceMotion ? Duration.zero : (45 * index).ms,
                      duration: duration,
                    )
                    .slideX(begin: 0.025, end: 0, duration: duration),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.companion,
    required this.heroTag,
    required this.onTap,
  });

  final Companion companion;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CompanionAvatar(companion: companion, size: 58, heroTag: heroTag),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(companion.name, style: Theme.of(context).textTheme.titleMedium)),
                      Text(companion.lastTime, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          companion.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (companion.unread > 0) ...[
                        const SizedBox(width: 8),
                        Badge(label: Text('${companion.unread}')),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 12),
          Text('没有找到这段对话', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('试试搜索陪伴者的名字', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}
