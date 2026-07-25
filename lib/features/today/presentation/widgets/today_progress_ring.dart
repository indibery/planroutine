import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// 오늘의 결산 링 — 체크할 때마다 골드가 차오르고, 마지막 한 건에서 펄스가 터진다.
///
/// 지난 항목은 세지 않는다(오늘 항목만) — 섞이면 1.0에 도달할 수 없다.
class TodayProgressRing extends StatefulWidget {
  const TodayProgressRing({
    super.key,
    required this.done,
    required this.total,
  });

  final int done;
  final int total;

  static const _diameter = 74.0;
  static const _stroke = 7.0;

  double get _progress => total == 0 ? 0 : done / total;

  bool get _isAllDone => total > 0 && done == total;

  @override
  State<TodayProgressRing> createState() => _TodayProgressRingState();
}

class _TodayProgressRingState extends State<TodayProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(TodayProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 완주하는 순간에만 한 번 — 이미 완주한 상태로 재빌드될 때는 울리지 않는다.
    if (widget._isAllDone && !oldWidget._isAllDone) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // 0 → 1 → 0 벨커브 하나로 확대와 글로우를 함께 만든다.
        final glow = math.sin(_pulse.value * math.pi);
        return Transform.scale(
          scale: 1 + 0.07 * glow,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: glow > 0
                  ? [
                      BoxShadow(
                        color: AppColors.goldFill.withValues(alpha: glow * 0.5),
                        blurRadius: 14 * glow,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        );
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget._progress),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: value,
              trackColor: AppColors.surfaceVariant,
              valueColor: AppColors.goldFill,
            ),
            child: SizedBox(
              width: TodayProgressRing._diameter,
              height: TodayProgressRing._diameter,
              child: Center(
                child: Text(
                  '${widget.done}/${widget.total}',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: widget._isAllDone ? AppColors.gold : AppColors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.valueColor,
  });

  final double progress;
  final Color trackColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - TodayProgressRing._stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = TodayProgressRing._stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = TodayProgressRing._stroke
      ..strokeCap = StrokeCap.round
      ..color = valueColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // 12시 방향에서 시작
      2 * math.pi * progress,
      false,
      value,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.valueColor != valueColor;
}
