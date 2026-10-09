import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/arrival_text.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/next_bus.dart';
import 'bus_more_count.dart';
import 'bus_signal_color.dart';

/// `간단히` 본문 — **기본 모양.** 가장 먼저 오는 차를 한 줄로 크게, 나머지는 칩으로.
///
/// **분·초까지 쓴다**(사용자 결정 2026-10-09). 호스트가 1초마다 경과를 빼서 다시
/// 그리므로 초가 매끄럽게 줄어든다. 단, 서버 예측은 30초마다 평균 33초씩 고쳐지므로
/// (2026-07-30 실측) 다시 조회하는 순간 초가 튈 수 있다 — 정확도가 아니라 흐름을
/// 보여주는 표기다. `시간 축`은 분만 쓴다.
///
/// **신호색을 쓴다**(같은 날 사용자 결정 — 2026-07-28 스펙의 "기본 모양은 신호색 0"을
/// 뒤집었다). 대신 색을 칠하는 곳을 좁혔다: 줄 배경 틴트와 점은 세 칸 모두 칠하지만,
/// **글자를 색으로 쓰는 것은 3분 안의 빨강뿐이다.** 라이트의 노랑·초록 글자는 틴트
/// 위에서 2.6~3.0:1이라 큰 글자 기준도 못 넘는다.
///
/// 색 칸은 **보이는 분(내림)** 으로 고른다 — `2분 59초`를 반올림 3분(노랑)으로 칠하면
/// 사용자가 읽는 숫자와 색이 어긋난다.
class BusBodyText extends StatelessWidget {
  const BusBodyText({super.key, required this.view});

  /// 가장 먼저 오는 차의 강조 줄.
  static const firstKey = Key('bus_body_text_first');

  final BusCardView view;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final first = view.visible.first;
    final rest = view.visible.skip(1).toList();
    final next = nextBusMinutes(view);
    final hasTail = rest.isNotEmpty || next != null || view.hiddenCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _firstRow(first),
        if (hasTail) ...[
          const SizedBox(height: AppSizes.spacing8),
          Wrap(
            spacing: AppSizes.spacing8,
            runSpacing: AppSizes.spacing4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...rest.map(_chip),
              // **한 대만 보일 때만** 그 다음 차를 덧붙인다(`BusBodyAxis`도 같은 조건).
              if (next != null)
                Text(
                  BusStrings.nextBus(next),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    color: AppColors.sub,
                  ),
                ),
              // 감춘 개수는 `시간 축`과 **같은 위젯**으로 그린다(`BusMoreCount` 주석 참고).
              if (view.hiddenCount > 0)
                BusMoreCount(hiddenCount: view.hiddenCount),
            ],
          ),
        ],
      ],
    );
  }

  Widget _firstRow(BusArrival arrival) {
    final signal = busSignalOf(displayedMinutes(arrival.arrSec));
    final color = busSignalColor(signal);
    return Container(
      key: firstKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: Row(
        children: [
          _signalDot(color, 10),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BusStrings.firstBus,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sub,
                  ),
                ),
                Text(
                  BusStrings.routeLabel(arrival.routeNo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          Text(
            arrivalClockText(arrival.arrSec),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              fontFeatures: _tabular,
              // 글자에 색을 쓰는 것은 빨강뿐이다 — 클래스 주석 참고.
              color: signal == BusSignal.near
                  ? AppColors.busSignalNear
                  : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BusArrival arrival) {
    final color = busSignalColor(busSignalOf(displayedMinutes(arrival.arrSec)));
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _signalDot(color, 6),
          const SizedBox(width: 6),
          Text(
            BusStrings.routeLabel(arrival.routeNo),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: AppSizes.spacing4),
          Text(
            arrivalClockText(arrival.arrSec),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: _tabular,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  /// 색은 점이 말한다. 스크린리더에는 시간 글자가 이미 있어 점은 읽히지 않게 둔다.
  Widget _signalDot(Color color, double size) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
