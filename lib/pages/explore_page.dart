import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data.dart';
import '../widgets.dart';
import 'chat_page.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  void _openChat(BuildContext context) {
    final companion = companions.single;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(companion: companion, heroTag: 'explore-${companion.id}'),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final companion = companions.single;
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
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openChat(context);
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
    final companion = companions.single;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion ? Duration.zero : 280.ms;
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('explore-scroll'),
        padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 28),
        children: [
          const LumoPageTitle(title: '探索', subtitle: '认识此刻唯一开放的陪伴者'),
          const SizedBox(height: 24),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showDetails(context),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Hero(tag: 'explore-${companion.id}', child: CompanionAvatar(companion: companion, size: 96)),
                    const SizedBox(height: 16),
                    Text(companion.name, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(companion.tagline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: () => _openChat(context), child: const Text('和喵喵聊聊')),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: duration).slideY(begin: 0.04, end: 0, duration: duration),
          const SizedBox(height: 18),
          Text('更多智能体正在准备中。现在，喵喵会陪你慢慢把话说完。', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
