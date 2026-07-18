import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'data.dart';

double lumoHorizontalPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width > 640 ? (width - 600) / 2 : 20;
}

Duration lumoMotionDuration(BuildContext context, [int milliseconds = 240]) =>
    MediaQuery.of(context).disableAnimations
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class LumoMark extends StatelessWidget {
  const LumoMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Lumo 品牌标志',
    image: true,
    child: SvgPicture.asset(
      'assets/icons/lumo_mark.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
    ),
  );
}

class CompanionAvatar extends StatelessWidget {
  const CompanionAvatar({
    required this.companion,
    required this.size,
    this.heroTag,
    super.key,
  });

  final Companion companion;
  final double size;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final avatar = Semantics(
      label: '${companion.name}的头像',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.25, -0.3),
            colors: [companion.color.withValues(alpha: 0.58), companion.color],
          ),
          boxShadow: [
            BoxShadow(
              color: companion.color.withValues(alpha: 0.18),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 3,
          ),
        ),
        child: SizedBox.square(
          dimension: size,
          child: companion.avatarAsset != null
              ? ClipOval(
                  child: Image.asset(
                    companion.avatarAsset!,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.2),
                    excludeFromSemantics: true,
                  ),
                )
              : companion.avatarUrl != null
              ? ClipOval(
                  child: Image.network(
                    companion.avatarUrl!,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.2),
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) =>
                        _AvatarGlyph(companion: companion, size: size),
                  ),
                )
              : _AvatarGlyph(companion: companion, size: size),
        ),
      ),
    );
    return heroTag == null ? avatar : Hero(tag: heroTag!, child: avatar);
  }
}

class _AvatarGlyph extends StatelessWidget {
  const _AvatarGlyph({required this.companion, required this.size});

  final Companion companion;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      companion.glyph,
      style: TextStyle(
        fontFamily: 'LumoDisplay',
        color: Colors.white,
        fontSize: size * 0.36,
      ),
    ),
  );
}

class AgentCatalogNotice extends StatelessWidget {
  const AgentCatalogNotice({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$message 已显示本机列表。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}

class LumoPageTitle extends StatelessWidget {
  const LumoPageTitle({
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Text(
                eyebrow!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(title, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class LumoSectionHeader extends StatelessWidget {
  const LumoSectionHeader({required this.title, this.caption, super.key});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (caption != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(caption!, style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );
}

class LumoStatusPill extends StatelessWidget {
  const LumoStatusPill({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
