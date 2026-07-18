import 'package:flutter/material.dart';

import '../data.dart';
import '../widgets.dart';
import 'chat_page.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage(
      {required this.companions,
      required this.catalogError,
      required this.onRetry,
      super.key});

  final List<Companion> companions;
  final String? catalogError;
  final VoidCallback onRetry;

  void _openChat(BuildContext context, Companion companion) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatPage(companion: companion, heroTag: 'explore-${companion.id}'),
      ),
    );
  }

  void _showDetails(BuildContext context, Companion companion) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: SizedBox(
                    width: 190,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Hero(
                          tag: 'explore-${companion.id}',
                          child: _CompanionCover(companion: companion)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: Text(companion.name,
                            style: Theme.of(context).textTheme.headlineMedium)),
                    _CoverLabel(label: companion.isAvailable ? '在线' : '未开放'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(categoryLabel(companion.category),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Text(companion.tagline,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 10),
                Text(companion.people,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: companion.isAvailable
                        ? () {
                            Navigator.pop(sheetContext);
                            _openChat(context, companion);
                          }
                        : null,
                    child: Text(companion.isAvailable
                        ? '和${companion.name}聊聊'
                        : '暂未开放'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('explore-scroll'),
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 28),
        children: [
          const LumoPageTitle(title: '探索', subtitle: '认识这里的陪伴者'),
          if (catalogError != null) ...[
            const SizedBox(height: 16),
            AgentCatalogNotice(message: catalogError!, onRetry: onRetry),
          ],
          const SizedBox(height: 28),
          if (companions.isNotEmpty) ...[
            const LumoSectionHeader(title: '找到与你同频的人', caption: '轻触了解更多'),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 340 ? 2 : 1;
                final cardWidth =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 24,
                  children: [
                    for (final companion in companions)
                      SizedBox(
                        width: cardWidth,
                        child: _ExploreCard(
                          companion: companion,
                          onDetails: () => _showDetails(context, companion),
                          onChat: () => _openChat(context, companion),
                        ),
                      ),
                  ],
                );
              },
            ),
          ] else
            const _ExploreEmpty(),
        ],
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard(
      {required this.companion, required this.onDetails, required this.onChat});

  final Companion companion;
  final VoidCallback onDetails;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'explore-${companion.id}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onDetails,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _CompanionCover(companion: companion),
                      Positioned(
                          left: 10,
                          top: 10,
                          child: _CoverLabel(
                              label: categoryLabel(companion.category))),
                      Positioned(
                          right: 10,
                          top: 10,
                          child: _CoverLabel(
                              label: companion.isAvailable ? '在线' : '未开放')),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: Text(companion.name,
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                tooltip: '和${companion.name}聊聊',
                onPressed: companion.isAvailable ? onChat : null,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 21),
              ),
            ],
          ),
          Text(companion.tagline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _CompanionCover extends StatelessWidget {
  const _CompanionCover({required this.companion});

  final Companion companion;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: companion.color.withValues(alpha: 0.2),
      child: Center(child: CompanionAvatar(companion: companion, size: 88)),
    );
    final image = companion.avatarAsset != null
        ? Image.asset(companion.avatarAsset!,
            fit: BoxFit.cover,
            alignment: _alignment(companion.id),
            excludeFromSemantics: true)
        : companion.avatarUrl != null
            ? Image.network(
                companion.avatarUrl!,
                fit: BoxFit.cover,
                alignment: _alignment(companion.id),
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback;
    return Semantics(
      label: '${companion.name}的人物封面',
      image: true,
      excludeSemantics: true,
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: image),
    );
  }

  Alignment _alignment(String id) => switch (id) {
        'kun' => const Alignment(0, -0.35),
        'majiaqi' => const Alignment(0, -1),
        'songyaxuan' => const Alignment(0, -0.2),
        _ => const Alignment(0, -0.15),
      };
}

class _CoverLabel extends StatelessWidget {
  const _CoverLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(999)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      );
}

class _ExploreEmpty extends StatelessWidget {
  const _ExploreEmpty();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 72),
        child: Column(
          children: [
            Icon(Icons.explore_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 18),
            Text('暂无新的陪伴者', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('过一会儿再来看看吧', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}
