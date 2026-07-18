import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data.dart';
import '../widgets.dart';
import 'chat_page.dart';

class AgentsPage extends StatelessWidget {
  const AgentsPage({required this.companions, required this.catalogError, required this.onRetry, super.key});

  final List<Companion> companions;
  final String? catalogError;
  final VoidCallback onRetry;

  void _openChat(BuildContext context, Companion companion) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(companion: companion, heroTag: 'agents-${companion.id}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion ? Duration.zero : 260.ms;
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('agents-scroll'),
        padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 28),
        children: [
          const LumoPageTitle(title: '智能体', subtitle: '选择一位陪伴者延续对话'),
          if (catalogError != null) ...[
            const SizedBox(height: 16),
            AgentCatalogNotice(message: catalogError!, onRetry: onRetry),
          ],
          const SizedBox(height: 22),
          if (companions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('暂时没有已上线的智能体。', textAlign: TextAlign.center),
              ),
            ),
          for (var index = 0; index < companions.length; index++) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openChat(context, companions[index]),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CompanionAvatar(companion: companions[index], size: 64, heroTag: 'agents-${companions[index].id}'),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(companions[index].name, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(companions[index].tagline, style: Theme.of(context).textTheme.bodyMedium),
                            if (!companions[index].isAvailable) ...[
                              const SizedBox(height: 10),
                              Text('该智能体暂未开放，敬请期待', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: duration)
                .slideX(begin: 0.025, end: 0, duration: duration),
            if (index < companions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
