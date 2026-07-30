import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/next_bus.dart';
import 'bus_more_count.dart';

/// `간단히` 본문 — 한 줄에 노선을 나열한다. **기본 모양.**
///
/// 새 색 토큰을 하나도 참조하지 않는다. 임박은 굵기·크기로만 낸다 — 요일 헤더를
/// `본문색 + w700`으로 해결한 것과 같은 수법이다. 가드 테스트가 이 위젯이
/// **신호색 토큰을 쓰지 않는다**는 사실을 소스 문자열 검사로 지킨다.
///
/// 그 가드가 주석까지 통째로 훑기 때문에 **이 주석은 토큰 이름을 적지 않는다** —
/// 적으면 설명하려던 가드에 자기가 걸린다(이 문단을 고쳐 쓰다 두 번 걸렸다).
/// 가드를 멍청하게 두는 편이 값이 크다: 주석에 이름만 적어둔 미래 계획까지 잡힌다.
class BusBodyText extends StatelessWidget {
  const BusBodyText({super.key, required this.view});

  final BusCardView view;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.spacing16,
      runSpacing: AppSizes.spacing4,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        ...view.visible.map(_entry),
        // **한 대만 보일 때만** 그 다음 차를 덧붙인다(`BusBodyAxis`도 같은 조건).
        // 놓쳐도 얼마나 기다리는지가 이때 가장 궁금하다 — 대안이 화면에 없으니까.
        if (nextBusMinutes(view) case final next?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              BusStrings.nextBus(next),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                color: AppColors.faint,
              ),
            ),
          ),
        // 감춘 개수는 `시간 축`과 **같은 위젯**으로 그린다 — 인라인으로 두면
        // 한쪽에만 있는 상태가 다시 만들어진다(`BusMoreCount`의 주석 참고).
        if (view.hiddenCount > 0) BusMoreCount(hiddenCount: view.hiddenCount),
      ],
    );
  }

  Widget _entry(BusArrival arrival) {
    final urgent = isUrgent(arrival.arrMin);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          BusStrings.routeLabel(arrival.routeNo),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: urgent ? FontWeight.w700 : FontWeight.w600,
            color: urgent ? AppColors.ink : AppColors.sub,
          ),
        ),
        const SizedBox(width: AppSizes.spacing4),
        Text(
          arrival.arrMin == 0
              ? BusStrings.arrivingNow
              : BusStrings.minutes(arrival.arrMin),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: urgent ? 18 : 14,
            fontWeight: urgent ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: urgent ? -0.4 : 0,
            color: urgent ? AppColors.ink : AppColors.sub,
          ),
        ),
      ],
    );
  }
}
