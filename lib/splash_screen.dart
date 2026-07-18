import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class LumoSplash extends StatefulWidget {
  const LumoSplash({required this.ready, required this.onFinished, super.key});

  final bool ready;
  final VoidCallback onFinished;

  @override
  State<LumoSplash> createState() => _LumoSplashState();
}

class _LumoSplashState extends State<LumoSplash> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  late final AnimationController _waiting = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final AnimationController _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  Timer? _waitingTimer;
  bool _started = false;
  bool _introDone = false;
  bool _showWaiting = false;
  bool _finishing = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _introDone = true;
        _finishWhenReady();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _intro.value = 1;
      _introDone = true;
      _finishWhenReady();
      return;
    }
    _intro.forward();
    _waitingTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || widget.ready || _finishing) return;
      setState(() => _showWaiting = true);
      _waiting.repeat();
    });
  }

  @override
  void didUpdateWidget(covariant LumoSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.ready && widget.ready) _finishWhenReady();
  }

  void _finishWhenReady() {
    if (!_introDone || !widget.ready || _finishing) return;
    _finishing = true;
    _waitingTimer?.cancel();
    _waiting.stop();
    if (_reduceMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
      return;
    }
    _exit.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  double _segment(double value, double start, double end) => ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _intro.dispose();
    _waiting.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: LumoColors.canvas,
    ),
    child: Semantics(
      container: true,
      excludeSemantics: true,
      label: _showWaiting ? 'Lumo 正在准备陪伴，请稍候' : 'Lumo，点亮你的每一刻',
      child: Material(
        color: LumoColors.canvas,
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _waiting, _exit]),
          builder: (context, child) {
            final formation = _segment(_intro.value, 0.18, 0.54);
            final seed = _segment(_intro.value, 0, 0.18);
            final bodyScale = formation == 0
                ? ui.lerpDouble(0.025, 0.08, Curves.easeOut.transform(seed))!
                : ui.lerpDouble(0.08, 1, Curves.easeOutBack.transform(formation))!;
            final textProgress = Curves.easeOut.transform(_segment(_intro.value, 0.54, 0.9));
            final cushion = Curves.easeOut.transform(_segment(_intro.value, 0.54, 0.78));
            final openingEyes = Curves.easeOut.transform(_segment(_intro.value, 0.3, 0.54));
            final exitEye = _exit.value == 0 ? 1.0 : 1 - math.sin(_segment(_exit.value, 0, 0.62) * math.pi);
            final exitFade = 1 - _segment(_exit.value, 0.62, 1);
            final introBreath = _intro.value < 0.54 ? 0.0 : math.sin(_segment(_intro.value, 0.54, 1) * math.pi * 2);
            final waitWave = _showWaiting ? math.sin(_waiting.value * math.pi * 2) : 0.0;
            final scale = bodyScale * (1 + introBreath * 0.018 + _exit.value * 0.035);
            return Opacity(
              opacity: exitFade,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, 0.62),
                    radius: 1.05,
                    colors: [Color(0x52E7B998), Color(0xFFF3E6D9), LumoColors.canvas],
                    stops: [0, 0.5, 1],
                  ),
                ),
                child: SafeArea(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: 54 - (1 - textProgress) * 12,
                        left: 24,
                        right: 24,
                        child: Opacity(
                          opacity: textProgress,
                          child: const Text(
                            'Lumo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'LumoDisplay',
                              fontSize: 48,
                              color: LumoColors.ink,
                              shadows: [Shadow(color: Color(0x55E7B998), blurRadius: 14)],
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, 0.2),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = math.min(constraints.maxWidth * 0.82, 360.0);
                            return Transform.rotate(
                              angle: waitWave * 0.035,
                              child: Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: _segment(_intro.value, 0, 0.38),
                                  child: CustomPaint(
                                    size: Size.square(size),
                                    painter: _LumoMascotPainter(
                                      eyeOpen: (openingEyes * exitEye).clamp(0.0, 1.0).toDouble(),
                                      cushionOpacity: cushion,
                                      showWaiting: _showWaiting,
                                      waitWave: waitWave,
                                      pulse: math.sin(_exit.value * math.pi),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 64 - (1 - textProgress) * 12,
                        left: 24,
                        right: 24,
                        child: Opacity(
                          opacity: textProgress,
                          child: const Text(
                            '点亮你的每一刻',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, letterSpacing: 3, color: LumoColors.actionClay),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _LumoMascotPainter extends CustomPainter {
  const _LumoMascotPainter({
    required this.eyeOpen,
    required this.cushionOpacity,
    required this.showWaiting,
    required this.waitWave,
    required this.pulse,
  });

  final double eyeOpen;
  final double cushionOpacity;
  final bool showWaiting;
  final double waitWave;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyWidth = size.width * 0.78;
    final bodyHeight = bodyWidth / 1.05;
    final body = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.53), width: bodyWidth, height: bodyHeight);
    final outerGlow = Paint()
      ..color = const Color(0xFFFA709A).withValues(alpha: 0.22 + pulse * 0.12)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + pulse * 12);
    canvas.drawOval(body.inflate(size.width * (0.025 + pulse * 0.025)), outerGlow);

    final bodyPaint = Paint()
      ..shader = ui.Gradient.radial(
        body.center.translate(-body.width * 0.13, -body.height * 0.15),
        body.width * 0.62,
        const [Color(0xFFFEE140), Color(0xFFFFB13B), Color(0xFFFA709A)],
        const [0, 0.55, 1],
      );
    canvas.drawOval(body, bodyPaint);

    final fluff = Paint()..color = const Color(0xFFFA709A).withValues(alpha: 0.12);
    for (var i = 0; i < 140; i++) {
      final angle = i * math.pi * 2 / 140;
      final noise = math.sin(i * 12.9898) * 0.5 + 0.5;
      final x = body.center.dx + math.cos(angle) * (body.width / 2 + noise * 5 - 2);
      final y = body.center.dy + math.sin(angle) * (body.height / 2 + noise * 4 - 2);
      canvas.drawCircle(Offset(x, y), 1.2 + noise * 2.4, fluff);
    }

    final eyeRadius = body.width * 0.075;
    final eyeY = body.center.dy - body.height * 0.035;
    final eyeOffset = body.width * 0.19;
    _drawEye(canvas, Offset(body.center.dx - eyeOffset, eyeY), eyeRadius);
    _drawEye(canvas, Offset(body.center.dx + eyeOffset, eyeY), eyeRadius);

    final mouthRect = Rect.fromCenter(
      center: Offset(body.center.dx, body.center.dy + body.height * 0.16),
      width: body.width * 0.2,
      height: body.height * 0.11,
    );
    final mouthGlow = Paint()
      ..color = const Color(0xFFFFD93D).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.025
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final mouth = Paint()
      ..color = const Color(0xFFFFD93D)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.015;
    canvas.drawArc(mouthRect, 0, math.pi, false, mouthGlow);
    canvas.drawArc(mouthRect, 0, math.pi, false, mouth);

    if (cushionOpacity > 0) {
      final cushionRect = Rect.fromCenter(
        center: Offset(body.center.dx, body.bottom + size.height * 0.012),
        width: body.width * 0.6,
        height: body.height * 0.13,
      );
      final cushionGlow = Paint()
        ..color = const Color(0xFFFDB813).withValues(alpha: cushionOpacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.045
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      final cushion = Paint()
        ..color = const Color(0xFFFDB813).withValues(alpha: cushionOpacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.018;
      canvas.drawOval(cushionRect, cushionGlow);
      canvas.drawOval(cushionRect, cushion);
    }

    if (showWaiting) _drawWaitingBubble(canvas, size, body.top - size.height * 0.07);
  }

  void _drawEye(Canvas canvas, Offset center, double radius) {
    if (eyeOpen < 0.22) {
      final closed = Paint()
        ..color = const Color(0xFF4A2C1A)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * 0.24;
      canvas.drawArc(Rect.fromCenter(center: center, width: radius * 1.65, height: radius * 0.8), math.pi, math.pi, false, closed);
      return;
    }
    final eye = Rect.fromCenter(center: center, width: radius * 2, height: radius * 2 * eyeOpen);
    canvas.drawOval(eye, Paint()..color = const Color(0xFF4A2C1A));
    final highlight = Paint()..color = Colors.white;
    canvas.drawCircle(center.translate(-radius * 0.38, -radius * 0.35 * eyeOpen), radius * 0.23, highlight);
    canvas.drawCircle(center.translate(radius * 0.38, radius * 0.38 * eyeOpen), radius * 0.11, highlight);
  }

  void _drawWaitingBubble(Canvas canvas, Size size, double y) {
    final center = Offset(size.width / 2 + waitWave * 3, y);
    final bubble = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size.width * 0.2, height: size.height * 0.09),
      Radius.circular(size.width * 0.045),
    );
    final glow = Paint()
      ..color = const Color(0xFFFFD93D).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(bubble, glow);
    canvas.drawRRect(bubble, Paint()..color = LumoColors.paper);
    final dot = Paint()..color = const Color(0xFFFFD93D);
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(center.translate(i * size.width * 0.035, 0), size.width * 0.009, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LumoMascotPainter oldDelegate) =>
      eyeOpen != oldDelegate.eyeOpen ||
      cushionOpacity != oldDelegate.cushionOpacity ||
      showWaiting != oldDelegate.showWaiting ||
      waitWave != oldDelegate.waitWave ||
      pulse != oldDelegate.pulse;
}
