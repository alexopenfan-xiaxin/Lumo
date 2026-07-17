import 'package:flutter/material.dart';

import 'pages/agents_page.dart';
import 'pages/explore_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';

class LumoShell extends StatefulWidget {
  const LumoShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<LumoShell> createState() => _LumoShellState();
}

class _LumoShellState extends State<LumoShell> {
  int _index = 0;

  static const _destinations = [
    (label: '首页', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
    (label: '智能体', icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded),
    (label: '探索', icon: Icons.explore_outlined, selectedIcon: Icons.explore_rounded),
    (label: '设置', icon: Icons.tune_outlined, selectedIcon: Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 200);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomePage(),
          const AgentsPage(),
          const ExplorePage(),
          SettingsPage(
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (var index = 0; index < _destinations.length; index++)
                  Expanded(child: _DockItem(destination: _destinations[index], selected: index == _index, duration: duration, onTap: () => setState(() => _index = index))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({required this.destination, required this.selected, required this.duration, required this.onTap});

  final ({String label, IconData icon, IconData selectedIcon}) destination;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: destination.label,
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          height: 56,
          decoration: BoxDecoration(color: selected ? theme.colorScheme.primary.withValues(alpha: 0.14) : null, borderRadius: BorderRadius.circular(24)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? destination.selectedIcon : destination.icon, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              AnimatedSize(
                duration: duration,
                child: selected ? Padding(padding: const EdgeInsets.only(left: 6), child: Text(destination.label, style: Theme.of(context).textTheme.labelLarge)) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
