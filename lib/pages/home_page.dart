import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data.dart';
import '../widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _hasUnread = true;

  void _showNotice(NoticeItem notice) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NoticeSheet(notice: notice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion ? Duration.zero : 280.ms;
    final horizontalPadding = lumoHorizontalPadding(context);
    return SafeArea(
      child: CustomScrollView(
        key: const PageStorageKey('home-scroll'),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 28),
            sliver: SliverList.list(
              children: [
                LumoPageTitle(
                  title: 'Lumo',
                  subtitle: '下午好，愿你在这里慢下来',
                  trailing: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton.filledTonal(
                        tooltip: '消息通知',
                        onPressed: () {
                          setState(() => _hasUnread = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('消息已全部读过')),
                          );
                        },
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      if (_hasUnread)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: Semantics(
                            label: '3 条未读消息',
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _WelcomeHero(onTap: () => _showNotice(notices[1]))
                    .animate()
                    .fadeIn(duration: duration)
                    .slideY(begin: 0.04, end: 0, duration: duration),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('公告', style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      '保持知情，也保留安静',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < notices.length; i++) ...[
                  _NoticeCard(
                    notice: notices[i],
                    onTap: () => _showNotice(notices[i]),
                  )
                      .animate()
                      .fadeIn(delay: reduceMotion ? Duration.zero : (60 * i).ms, duration: duration)
                      .slideY(begin: 0.04, end: 0, duration: duration),
                  if (i != notices.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '打开七日微光计划',
    child: Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/lumo_companions.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.1),
                cacheWidth: 1200,
              semanticLabel: 'Lumo 的晨光插画',
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB82B2622)],
                    stops: [0.3, 1],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '七日微光计划',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'LumoDisplay',
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '每天一分钟，照见此刻的自己',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.onTap});

  final NoticeItem notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: notice.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(notice.icon, color: notice.color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: notice.color.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          notice.tag,
                          style: TextStyle(color: notice.color, fontSize: 11),
                        ),
                      ),
                      const Spacer(),
                      Text(notice.time, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(notice.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(notice.description, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NoticeSheet extends StatelessWidget {
  const _NoticeSheet({required this.notice});

  final NoticeItem notice;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: notice.color.withValues(alpha: 0.15),
            child: Icon(notice.icon, color: notice.color),
          ),
          const SizedBox(height: 18),
          Text(notice.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('${notice.tag} · ${notice.time}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          Text(notice.detail, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ),
        ],
      ),
    ),
  );
}
