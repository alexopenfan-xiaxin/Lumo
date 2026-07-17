import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data.dart';
import '../widgets.dart';
import 'chat_page.dart';

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  void _openChat(BuildContext context) {
    final companion = companions.single;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(companion: companion, heroTag: 'agents-${companion.id}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companion = companions.single;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion ? Duration.zero : 260.ms;
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('agents-scroll'),
        padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 28),
        children: [
          const LumoPageTitle(title: '智能体', subtitle: '和喵喵延续每一段对话'),
          const SizedBox(height: 22),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openChat(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CompanionAvatar(companion: companion, size: 64, heroTag: 'agents-${companion.id}'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(companion.name, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(companion.tagline, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 10),
                          Text('本机保存的会话可在聊天页切换', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: duration).slideX(begin: 0.025, end: 0, duration: duration),
        ],
      ),
    );
  }
}
