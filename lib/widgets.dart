import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'data.dart';

double lumoHorizontalPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width > 640 ? (width - 600) / 2 : 20;
}

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
            colors: [
              companion.color.withValues(alpha: 0.58),
              companion.color,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: companion.color.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Text(
              companion.glyph,
              style: TextStyle(
                fontFamily: 'LumoDisplay',
                color: Colors.white,
                fontSize: size * 0.36,
              ),
            ),
          ),
        ),
      ),
    );
    return heroTag == null ? avatar : Hero(tag: heroTag!, child: avatar);
  }
}

class LumoPageTitle extends StatelessWidget {
  const LumoPageTitle({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}
