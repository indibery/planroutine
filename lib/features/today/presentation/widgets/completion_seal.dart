import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/stamp_settings.dart';

/// 완료 도장 — 체크하는 순간 화면 밖 크기에서 떨어져 −10°로 앉는다.
///
/// [animation] 0 → 1 구간에서 낙하가 재생되고, 1에서 남아 "처리됨"의 증표가 된다.
/// 이미 완료된 상태로 그려지는 행은 `AlwaysStoppedAnimation(1)`을 넘겨 도장이 처음부터
/// 찍혀 있게 한다.
///
/// [style]에 따라 모양이 바뀌고(원형/사각, 글자/아이콘), [dimmed]면 잔상처럼 옅게 찍는다.
class CompletionSeal extends StatelessWidget {
  const CompletionSeal({
    super.key,
    required this.animation,
    this.style = SealStyle.complete,
    this.dimmed = false,
  });

  final Animation<double> animation;
  final SealStyle style;

  /// 화면 진입 시 이미 찍혀 있던 도장 — 방금 찍은 것과 구분해 옅게 남긴다.
  final bool dimmed;

  /// 지름. 행 우측 도장 슬롯(56)보다 작게 둬 글자와 붙지 않는다.
  static const _size = 44.0;

  /// 안착 후 남는 불투명도. 방금 찍은 도장은 진하게, 지난 도장은 잔상처럼.
  static const _restOpacity = 0.88;
  static const _dimmedOpacity = 0.32;

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

  static final Animatable<double> _rotation = Tween<double>(
    begin: -26 * math.pi / 180,
    end: -10 * math.pi / 180,
  ).chain(CurveTween(curve: Curves.easeOut));

  /// 낙하 초반에 0 → 1로 나타난 뒤 안착 불투명도로 잦아든다.
  Animatable<double> get _opacity => TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: _restingOpacity),
          weight: 70,
        ),
      ]);

  double get _restingOpacity => dimmed ? _dimmedOpacity : _restOpacity;

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
    // 사각 도장은 모서리를 살짝 둥글려 실제 결재 도장의 인상에 가깝게.
    final radius = style.isSquare
        ? BorderRadius.circular(AppSizes.radius8)
        : BorderRadius.circular(_size);

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.goldFill, width: 2.5),
      ),
      child: Padding(
        // 안쪽 얇은 테두리 한 겹 — 실제 도장의 이중 테두리 인상.
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: style.isSquare
                ? BorderRadius.circular(AppSizes.radius4)
                : radius,
            border: Border.all(
              color: AppColors.goldFill.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Center(child: _mark()),
        ),
      ),
    );
  }

  Widget _mark() {
    if (style.usesIcon) {
      return Icon(
        Icons.thumb_up_alt_rounded,
        size: 19,
        color: AppColors.gold,
      );
    }
    return Text(
      style.label,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.gold,
      ),
    );
  }
}
