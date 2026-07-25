import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

/// 완료 도장 — 체크하는 순간 화면 밖 크기에서 떨어져 −10°로 앉는다.
///
/// [animation] 0 → 1 구간에서 낙하가 재생되고, 1에서 opacity 0.88로 남아 "처리됨"의
/// 증표가 된다. 이미 완료된 상태로 그려지는 행은 `AlwaysStoppedAnimation(1)`을 넘겨
/// 도장이 처음부터 찍혀 있게 한다.
class CompletionSeal extends StatelessWidget {
  const CompletionSeal({super.key, required this.animation});

  final Animation<double> animation;

  /// 지름. 행 우측 도장 슬롯(56)보다 작게 둬 글자와 붙지 않는다.
  static const _size = 44.0;

  static final Animatable<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 2.4, end: 0.92).chain(
        CurveTween(curve: Curves.easeIn),
      ),
      weight: 55,
    ),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.05), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 25),
  ]);

  static final Animatable<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 70),
  ]);

  static final Animatable<double> _rotation = Tween<double>(
    begin: -26 * math.pi / 180,
    end: -10 * math.pi / 180,
  ).chain(CurveTween(curve: Curves.easeOut));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: _opacity.evaluate(animation).clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: _rotation.evaluate(animation),
            child: Transform.scale(
              scale: _scale.evaluate(animation),
              child: _stamp(),
            ),
          ),
        );
      },
    );
  }

  Widget _stamp() {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldFill, width: 2.5),
      ),
      child: Padding(
        // 안쪽 얇은 테두리 한 겹 — 실제 결재 도장의 이중 원 인상.
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.goldFill.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Center(
            child: Text(
              TodayStrings.sealLabel,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.gold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
