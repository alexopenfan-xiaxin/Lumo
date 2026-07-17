import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data.dart';
import '../widgets.dart';
import 'chat_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  CompanionCategory _category = CompanionCategory.all;

  void _openChat(Companion companion) {
    final heroTag = 'explore-${companion.id}';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(companion: companion, heroTag: heroTag),
      ),
    );
  }

  void _showDetails(Companion companion) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionAvatar(companion: companion, size: 78),
              const SizedBox(height: 16),
              Text(companion.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                companion.tagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(companion.people, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openChat(companion);
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('开始聊天'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _category == CompanionCategory.all
        ? companions
        : companions.where((companion) => companion.category == _category).toList();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion ? Duration.zero : 280.ms;
    final horizontalPadding = lumoHorizontalPadding(context);

    return SafeArea(
      child: CustomScrollView(
        key: const PageStorageKey('explore-scroll'),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 14),
            sliver: SliverList.list(
              children: [
                const LumoPageTitle(title: '探索', subtitle: '找到更适合此刻的陪伴方式'),
                const SizedBox(height: 20),
                _ExploreHero(onTap: () => _showDetails(companions.first))
                    .animate()
                    .fadeIn(duration: duration)
                    .slideY(begin: 0.04, end: 0, duration: duration),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final category in CompanionCategory.values) ...[
                        ChoiceChip(
                          label: Text(categoryLabel(category)),
                          selected: _category == category,
                          onSelected: (_) => setState(() => _category = category),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 6, horizontalPadding, 28),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _CompanionCard(
                companion: filtered[index],
                heroTag: 'explore-${filtered[index].id}',
                onTap: () => _showDetails(filtered[index]),
                onChat: () => _openChat(filtered[index]),
              )
                  .animate(key: ValueKey('${_category.name}-$index'))
                  .fadeIn(
                    delay: reduceMotion ? Duration.zero : (50 * index).ms,
                    duration: duration,
                  )
                  .slideY(begin: 0.035, end: 0, duration: duration),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreHero extends StatelessWidget {
  const _ExploreHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 188,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/lumo_companions.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.05),
              cacheWidth: 1200,
              semanticLabel: '不同性格的情绪陪伴者',
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB82B2622)],
                ),
              ),
            ),
            const Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '精选智能体',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'LumoDisplay',
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text('为你匹配最合适的陪伴者', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({
    required this.companion,
    required this.heroTag,
    required this.onTap,
    required this.onChat,
  });

  final Companion companion;
  final String heroTag;
  final VoidCallback onTap;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CompanionAvatar(companion: companion, size: 62, heroTag: heroTag),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(companion.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(companion.tagline, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: companion.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    categoryLabel(companion.category),
                    style: TextStyle(color: companion.color, fontSize: 12),
                  ),
                ),
                Text(
                  companion.people,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                FilledButton(onPressed: onChat, child: const Text('开始聊天')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
