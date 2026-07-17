import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data.dart';
import '../widgets.dart';
import 'chat_page.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

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
    final duration = reduceMotion ? Duration.zero : 280.ms;
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('explore-scroll'),
        padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 28),
        children: [
          const LumoPageTitle(title: '探索', subtitle: '认识这里的陪伴者'),
          const SizedBox(height: 24),
          for (var index = 0; index < companions.length; index++) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showDetails(context, companions[index]),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Hero(tag: 'explore-${companions[index].id}', child: CompanionAvatar(companion: companions[index], size: 96)),
                      const SizedBox(height: 16),
                      Text(companions[index].name, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(companions[index].tagline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: companions[index].isAvailable ? () => _openChat(context, companions[index]) : null,
                        child: Text(companions[index].isAvailable ? '和${companions[index].name}聊聊' : '暂未开放'),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: duration).slideY(begin: 0.04, end: 0, duration: duration),
            if (index < companions.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
