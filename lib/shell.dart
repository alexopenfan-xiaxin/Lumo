import 'package:flutter/material.dart';

import 'agent_client.dart';
import 'data.dart';
import 'pages/agents_page.dart';
import 'pages/explore_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';

class LumoShell extends StatefulWidget {
  const LumoShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    this.onReady,
    super.key,
  });

  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeModeChanged;
  final VoidCallback? onReady;

  @override
  State<LumoShell> createState() => _LumoShellState();
}

class _LumoShellState extends State<LumoShell> {
  int _index = 0;
  bool _draggingSelection = false;
  final _dockKey = GlobalKey();
  List<Companion> _companions = companions;
  String? _catalogError;
  bool _reportedReady = false;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _catalogError = null);
    try {
      final loaded = await const AgentClient().fetchAgents();
      if (mounted) setState(() => _companions = loaded);
    } on AgentCatalogException catch (error) {
      if (mounted) setState(() => _catalogError = error.message);
    } finally {
      if (mounted && !_reportedReady) {
        _reportedReady = true;
        widget.onReady?.call();
      }
    }
  }

  static const _destinations = [
    _DockDestination(
      label: '首页',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _DockDestination(
      label: '智能体',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
    ),
    _DockDestination(
      label: '探索',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
    ),
    _DockDestination(
      label: '个人',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  void _select(int index) {
    if (index != _index) setState(() => _index = index);
  }

  int _indexAt(double position, double width) =>
      (position / (width / _destinations.length))
          .floor()
          .clamp(0, _destinations.length - 1)
          .toInt();

  double _dockPosition(Offset globalPosition) {
    final box = _dockKey.currentContext!.findRenderObject()! as RenderBox;
    return box.globalToLocal(globalPosition).dx;
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomePage(),
          AgentsPage(
            companions: _companions,
            catalogError: _catalogError,
            onRetry: _loadAgents,
          ),
          ExplorePage(
            companions: _companions,
            catalogError: _catalogError,
            onRetry: _loadAgents,
          ),
          ProfilePage(
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _FloatingDock(
          destinations: _destinations,
          selectedIndex: _index,
          duration: duration,
          onSelected: _select,
          dragKey: _dockKey,
          onDragStart: (position, width) => _draggingSelection =
              _indexAt(_dockPosition(position), width) == _index,
          onDragUpdate: (position, width) {
            if (_draggingSelection) {
              _select(_indexAt(_dockPosition(position), width));
            }
          },
          onDragEnd: () => _draggingSelection = false,
        ),
      ),
    );
  }
}

class _FloatingDock extends StatelessWidget {
  const _FloatingDock({
    required this.destinations,
    required this.selectedIndex,
    required this.duration,
    required this.onSelected,
    required this.dragKey,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final List<_DockDestination> destinations;
  final int selectedIndex;
  final Duration duration;
  final ValueChanged<int> onSelected;
  final GlobalKey dragKey;
  final void Function(Offset position, double width) onDragStart;
  final void Function(Offset position, double width) onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 62,
      child: LayoutBuilder(
        builder: (context, constraints) => Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Listener(
            key: dragKey,
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) =>
                onDragStart(event.position, constraints.maxWidth),
            onPointerMove: (event) =>
                onDragUpdate(event.position, constraints.maxWidth),
            onPointerUp: (_) => onDragEnd(),
            onPointerCancel: (_) => onDragEnd(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    Expanded(
                      child: _DockItem(
                        destination: destinations[index],
                        selected: index == selectedIndex,
                        duration: duration,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final _DockDestination destination;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      key: ValueKey('dock-${destination.label}'),
      label: destination.label,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DockIcon(
              destination: destination,
              selected: selected,
              color: color,
              duration: duration,
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: duration,
              curve: Curves.easeOutCubic,
              style: theme.textTheme.labelLarge!.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: ExcludeSemantics(child: Text(destination.label)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.destination,
    required this.selected,
    required this.color,
    required this.duration,
  });

  final _DockDestination destination;
  final bool selected;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    duration: duration,
    curve: Curves.easeOutCubic,
    tween: ColorTween(end: color),
    builder: (context, value, child) => Icon(
      selected ? destination.selectedIcon : destination.icon,
      color: value,
    ),
  );
}

class _DockDestination {
  const _DockDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
