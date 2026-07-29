import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/stamp_settings.dart';
import 'seal_gecko_mark.dart';
import 'seal_panda_mark.dart';

/// 완료 도장 — 체크하는 순간 화면 밖 크기에서 떨어져 −10°로 앉는다.
///
/// [animation] 0 → 1 구간에서 낙하가 재생되고, 1에서 남아 "처리됨"의 증표가 된다.
/// 이미 완료된 상태로 그려지는 행은 `AlwaysStoppedAnimation(1)`을 넘겨 도장이 처음부터
/// 찍혀 있게 한다.
///
/// [style]에 따라 모양이 바뀌고(원형/사각, 글자·판다), [dimmed]면 잔상처럼 옅게 찍는다.
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

  static const _outerBorder = 2.5;
  static const _innerPadding = 3.0;
  static const _innerBorder = 0.8;

  /// 이중 테두리 안쪽에 글자가 놓일 수 있는 폭.
  /// 문구를 바꿀 때 이 폭을 넘으면 글자가 깨진다(테스트가 지킨다).
  static const innerWidth =
      _size - 2 * (_outerBorder + _innerPadding + _innerBorder);

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

  /// 안착 각도 — 낙하가 끝난 도장이 앉는 기울기. 페이드아웃은 이 각도를 유지한다.
  static const _restAngle = -10 * math.pi / 180;

  static final Animatable<double> _rotation = Tween<double>(
    begin: -26 * math.pi / 180,
    end: _restAngle,
  ).chain(CurveTween(curve: Curves.easeOut));

  /// 낙하 초반에 0 → 1로 나타난 뒤 안착 불투명도로 잦아든다.
  ///
  /// dimmed 여부로 도착점만 갈리므로 둘을 미리 만들어 둔다. getter로 두면
  /// AnimatedBuilder 안에서 읽혀 프레임마다 TweenSequence가 새로 생긴다.
  static final Animatable<double> _opacityFull = _opacityTo(_restOpacity);
  static final Animatable<double> _opacityDimmed = _opacityTo(_dimmedOpacity);

  /// 안착 후 유지되는 불투명도(흐리게 설정 반영).
  double get _restingOpacity => dimmed ? _dimmedOpacity : _restOpacity;

  static Animatable<double> _opacityTo(double resting) => TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: resting), weight: 70),
      ]);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // 완료 취소(reverse)는 낙하의 역재생이 아니라 **제자리 페이드아웃**이다.
        // 같은 곡선을 거꾸로 돌리면 사라지는 동안 도장이 scale 2.4쪽으로 부풀어
        // 슬롯(56)을 넘어 제목을 덮고, 불투명도도 안착값보다 진해진다.
        final fadingOut = animation.status == AnimationStatus.reverse;
        final t = animation.value;

        return Opacity(
          // 페이드아웃은 안착 불투명도에서 0으로 선형 감쇠(t가 1 → 0).
          opacity: fadingOut
              ? t * _restingOpacity
              : (dimmed ? _opacityDimmed : _opacityFull).evaluate(animation),
          child: Transform.rotate(
            angle: fadingOut ? _restAngle : _rotation.evaluate(animation),
            child: Transform.scale(
              scale: fadingOut ? 1 : _scale.evaluate(animation),
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
      // 안쪽 얇은 테두리 한 겹 — 실제 도장의 이중 테두리 인상.
      padding: const EdgeInsets.all(_innerPadding),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.goldFill, width: _outerBorder),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: style.isSquare
              ? BorderRadius.circular(AppSizes.radius4)
              : radius,
          border: Border.all(
            color: AppColors.goldFill.withValues(alpha: 0.6),
            width: _innerBorder,
          ),
        ),
        child: Center(child: _mark()),
      ),
    );
  }

  /// **`switch`로 둔다.** 모양을 추가하면 컴파일러가 여기 누락을 잡는다 — 불린
  /// 분기였을 때는 새 모양이 조용히 글자 도장으로 그려졌다.
  Widget _mark() {
    return switch (style.mark) {
      SealMark.panda => SealPandaMark(color: AppColors.gold),
      SealMark.gecko => SealGeckoMark(color: AppColors.gold),
      SealMark.text => Text(
          style.label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.gold,
          ),
        ),
    };
  }
}
