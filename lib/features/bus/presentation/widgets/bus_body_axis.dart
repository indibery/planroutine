import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_card_view.dart';

/// `시간 축` 본문 — 0~15분 축에 버스를 점으로 놓는다.
///
/// 간격이 공간으로 보여 "이거 놓치면 6분 더"가 숫자 없이 읽힌다. 대신 두 버스가
/// 3분 안으로 붙으면 점과 라벨이 겹치고 15분 넘는 버스는 오른쪽 끝에 몰린다 —
/// 그래서 기본값이 아니라 선택지다.
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
        _scale(),
        const SizedBox(height: 2),
        SizedBox(height: 14, child: _rail()),
        const SizedBox(height: 2),
        SizedBox(height: 15, child: _labels()),
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
            );
          }).toList(),
        );
      },
    );
  }
}
