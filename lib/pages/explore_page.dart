import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data.dart';
import '../widgets.dart';
import 'chat_page.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({required this.companions, required this.catalogError, required this.onRetry, super.key});

  final List<Companion> companions;
  final String? catalogError;
  final VoidCallback onRetry;

  void _openChat(BuildContext context, Companion companion) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(companion: companion, heroTag: 'explore-${companion.id}'),
      ),
    );
  }

  void _showDetails(BuildContext context, Companion companion) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionAvatar(companion: companion, size: 88),
              const SizedBox(height: 16),
              Text(companion.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(companion.tagline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              Text(companion.people, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: companion.isAvailable
                      ? () {
                          Navigator.pop(sheetContext);
                          _openChat(context, companion);
                        }
                      : null,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(companion.isAvailable ? '开始聊天' : '暂未开放'),
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = lumoMotionDuration(context, 280);
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('explore-scroll'),
        padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 28),
        children: [
          const LumoPageTitle(title: '探索', subtitle: '认识这里的陪伴者', eyebrow: 'DISCOVER'),
          if (catalogError != null) ...[
            const SizedBox(height: 16),
            AgentCatalogNotice(message: catalogError!, onRetry: onRetry),
          ],
          const SizedBox(height: 24),
          if (companions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('新的陪伴者正在准备中。', textAlign: TextAlign.center),
              ),
            ),
          if (companions.isNotEmpty) ...[
            const LumoSectionHeader(title: '找到与你同频的人', caption: '轻触了解更多'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 520 ? 2 : 1;
                final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var index = 0; index < companions.length; index++)
                      SizedBox(
                        width: cardWidth,
                        child: _ExploreCard(
                          companion: companions[index],
                          onDetails: () => _showDetails(context, companions[index]),
                          onChat: () => _openChat(context, companions[index]),
                        )
                            .animate()
                            .fadeIn(delay: reduceMotion ? Duration.zero : (55 * index).ms, duration: duration)
                            .slideY(begin: 0.035, end: 0, duration: duration),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.companion, required this.onDetails, required this.onChat});

  final Companion companion;
  final VoidCallback onDetails;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Hero(tag: 'explore-${companion.id}', child: CompanionAvatar(companion: companion, size: 92)),
          const SizedBox(height: 16),
          Text(companion.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          LumoStatusPill(label: categoryLabel(companion.category), color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            companion.tagline,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: companion.isAvailable ? onChat : null,
              child: Text(companion.isAvailable ? '和${companion.name}聊聊' : '暂未开放'),
            ),
          ),
          SizedBox(width: double.infinity, child: TextButton(onPressed: onDetails, child: const Text('了解更多'))),
        ],
      ),
    ),
  );
}
