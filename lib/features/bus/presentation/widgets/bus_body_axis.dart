import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_card_view.dart';
import 'bus_more_count.dart';

/// `시간 축` 본문 — 0~15분 축에 버스를 점으로 놓는다.
///
/// 간격이 공간으로 보여 "이거 놓치면 6분 더"가 숫자 없이 읽힌다. 대신 두 버스가
/// 3분 안으로 붙으면 점과 라벨이 겹치고 15분 넘는 버스는 오른쪽 끝에 몰린다 —
/// 그래서 기본값이 아니라 선택지다.
///
/// **`간단히`와 같은 정보를 그린다.** 다른 것은 배치뿐이다 — 감춘 개수를 축에만
/// 빼면 모양을 바꾼 사용자만 조용히 손해를 본다([BusMoreCount] 주석 참고).
class BusBodyAxis extends StatelessWidget {
  const BusBodyAxis({super.key, required this.view});

  /// 축이 담는 최대 분.
  static const axisRange = 15;

  static const _minFraction = 0.03;
  static const _maxFraction = 0.97;

  final BusCardView view;

  /// 축 위 위치를 0~1로. **양 끝에서 점이 반쯤 잘리지 않게 clamp한다.**
  static double dotPosition(int arrMin) {
    final raw = arrMin / axisRange;
    return raw.clamp(_minFraction, _maxFraction);
  }

  static Color _dotColor(int arrMin) {
    if (isUrgent(arrMin)) return AppColors.busSignalNear;
    if (isSoon(arrMin)) return AppColors.busSignalSoon;
    return AppColors.busSignalFar;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 눈금(`지금 · 5분 · 10분 · 15분`)은 **눈으로만** 읽는 좌표계다. 스크린리더가
        // 이것까지 읽으면 라벨의 실제 도착 시각과 섞여 숫자가 두 배로 들린다.
        ExcludeSemantics(child: _scale()),
        const SizedBox(height: 2),
        SizedBox(height: 14, child: _rail()),
        const SizedBox(height: 2),
        SizedBox(height: 15, child: _labels()),
        // **라벨 행(Stack) 안에 우측 정렬로 넣지 않는다.** 15분을 넘긴 버스의 라벨은
        // `dotPosition`이 0.97로 clamp해 오른쪽 끝에 고정되는데, 상한이 걸릴 만큼
        // 노선이 많은 정류장에서는 보이는 3개 중 하나가 15분 이상인 일이 흔하다
        // (예: 18·20·22분) — 겹치면 감추려던 정보가 또 안 읽힌다. 별 줄로 둔다.
        if (view.hiddenCount > 0) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: BusMoreCount(hiddenCount: view.hiddenCount),
          ),
        ],
      ],
    );
  }

  Widget _scale() {
    TextStyle style() => TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          color: AppColors.faint,
        );
    return Row(
      children: [
        Text(BusStrings.axisNow, style: style()),
        const Spacer(),
        Text(BusStrings.minutes(axisRange ~/ 3), style: style()),
        const Spacer(),
        Text(BusStrings.minutes(axisRange * 2 ~/ 3), style: style()),
        const Spacer(),
        Text(BusStrings.minutes(axisRange), style: style()),
      ],
    );
  }

  Widget _rail() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 6,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.busSignalOff,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ...view.visible.map((a) => _dot(a, width)),
          ],
        );
      },
    );
  }

  Widget _dot(BusArrival arrival, double width) {
    const size = 12.0;
    return Positioned(
      left: (dotPosition(arrival.arrMin) * width) - (size / 2),
      top: 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _dotColor(arrival.arrMin),
          // 화면 배경색으로 테두리를 둘러 레일과 겹칠 때 형태가 유지된다.
          // 카드 면 토큰(`glass`)을 쓰지 않는 이유: 다크에서 흰색 6% 반투명이라
          // 테두리로 쓰면 링으로 레일이 비쳐 형태 유지 목적이 되레 깨진다.
          // 카드 면에 해당하는 불투명 토큰이 팔레트에 없어 근사치를 쓴다.
          border: Border.all(color: AppColors.background, width: 2),
        ),
      ),
    );
  }

  Widget _labels() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: view.visible.map((a) {
            final urgent = isUrgent(a.arrMin);
            return Positioned(
              left: (dotPosition(a.arrMin) * width) - 14,
              top: 0,
              width: 28,
              // **도착 시각을 라벨에 실어 준다.** 이 모양은 분을 화면 위치로만
              // 인코딩하므로(점은 색뿐이고 라벨은 노선번호뿐이다) 감싸지 않으면
              // 스크린리더에는 `720`·`150`이 맥락 없이 읽혀 정보가 0이 된다 —
              // `간단히`가 `720번` + `2분`을 읽어 주는 것과 같은 사실을 말해야 한다.
              // 문구는 `간단히`와 **같은 상수**를 쓴다(두 모양이 갈라지지 않게).
              // 목록의 중요 ★를 `Semantics`로 감싼 것과 같은 수법이다.
              child: Semantics(
                label: '${BusStrings.routeLabel(a.routeNo)} '
                    '${a.arrMin == 0 ? BusStrings.arrivingNow : BusStrings.minutes(a.arrMin)}',
                excludeSemantics: true,
                child: Text(
                  a.routeNo,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: urgent ? AppColors.ink : AppColors.sub,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
