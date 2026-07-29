import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_card_style.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/commute_direction.dart';
import 'bus_body_axis.dart';
import 'bus_body_text.dart';
import 'bus_empty_state.dart';

/// 오늘 탭 최상단 버스 카드.
///
/// **제목줄 전체가 접기/펼치기다.** chevron을 오른쪽 끝에 고정해 접든 펼치든
/// 표적이 움직이지 않는다 — `_overdueHeader`(`기한이 지난`)와 같은 구조다.
/// 접힌 상태를 별도 pill로 만들지 않는 이유도 여기다: 컨테이너가 모양을 바꾸면
/// 제목줄이 미묘하게 이동해 "같은 칸"이 깨진다.
class BusArrivalCard extends StatelessWidget {
  const BusArrivalCard({
    super.key,
    required this.view,
    required this.style,
    required this.direction,
    required this.stopName,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onFlipDirection,
    this.onRetry,
    this.onRegister,
    this.retrying = false,
  });

  static const headerKey = Key('bus_card_header');
  static const flipKey = Key('bus_card_flip');

  final BusCardView view;
  final BusCardStyle style;
  final CommuteDirection direction;

  /// 빈 문자열이면 제목줄의 `· 정류장` 세그먼트를 그리지 않는다(정류장 미등록 카드).
  final String stopName;
  final bool expanded;

  /// null이면 제목줄이 **정보 줄**이 된다 — 탭도, chevron도 없다.
  ///
  /// 정류장 미등록 카드가 `expanded: true` + 빈 콜백을 넘기던 시절에는 눌러도 아무
  /// 일이 없는 `Icons.expand_less`가 그려지고 스크린리더가 `접기`라고 읽었다.
  /// nullable로 두어 "접을 수 없는 카드"를 타입으로 표현한다.
  final VoidCallback? onToggleExpanded;
  final VoidCallback onFlipDirection;
  final VoidCallback? onRetry;
  final VoidCallback? onRegister;

  /// [onRetry]로 시작한 조회가 비행 중인가 — [BusEmptyState]에 그대로 넘긴다.
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.spacing12,
        AppSizes.pagePadding,
        AppSizes.spacing8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(color: AppColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 제목줄만 폭을 알아야 한다(좁은 폭에서 방향 라벨의 이모지를 뗀다).
          LayoutBuilder(
            builder: (context, constraints) => _header(constraints.maxWidth),
          ),
          if (expanded) ...[
            const SizedBox(height: AppSizes.spacing8),
            _body(),
            const SizedBox(height: AppSizes.spacing4),
            // **`view.hasRows` 게이트를 두지 않는다.** 사라지는 조건은 접힘 하나다
            // (스펙 §1). 목록이 비었을 때도 토글을 지우면, 출근 정류장만 등록한
            // 사용자가 퇴근 시간대에 열었을 때 `정류장을 등록하면 도착시간이
            // 보여요`만 있고 이미 등록해 둔 반대 방향으로 갈 길이 없는 막힌 카드가
            // 된다. 막차 후(`오늘 운행이 끝났어요`)에 다음 방향을 볼 길도 막힌다.
            _flip(),
          ],
        ],
      ),
    );
  }

  /// 방향 라벨에서 이모지를 떼는 본문 폭.
  ///
  /// 320pt 기기(화면 확대를 켠 아이폰 · 배포 타깃 iOS 13이 포함하는 SE 1세대)의 본문 폭은
  /// 280pt이고, 거기서 `stale` 제목줄의 고정 요소 셋(방향 라벨 · `07:32 기준 · 갱신 실패` ·
  /// chevron)이 합쳐 약 301pt였다 — `Expanded`인 정류장 이름을 0으로 줄여도 21px이 넘쳤다.
  /// 375pt 기기는 본문 335pt로 이 문턱 위라 **1픽셀도 바뀌지 않는다.**
  static const _shortLabelWidth = 300.0;

  Widget _header(double maxWidth) {
    final toggle = onToggleExpanded;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          maxWidth < _shortLabelWidth ? direction.shortLabel : direction.label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: AppSizes.spacing8),
        // 이름이 없으면 세그먼트를 통째로 생략한다 — `'· $stopName'`을 무조건 그리면
        // 정류장을 등록하기 전 첫 카드의 제목줄이 `출근   · `로 끝나 잘린 것처럼 보인다.
        // 자리는 Spacer가 지켜 오른쪽 끝 요소가 움직이지 않는다.
        if (stopName.isEmpty)
          const Spacer()
        else
          Expanded(
            child: Text(
              '· $stopName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: AppColors.sub,
              ),
            ),
          ),
        // 접히면 기준시각도 사라진다 — 폴링을 멈추니 신선도를 말할 근거가 없다.
        if (expanded && _stamp() != null) ...[
          Text(
            _stamp() ?? '',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 10,
              color: view.state == BusCardState.stale
                  ? AppColors.inkRed
                  : AppColors.faint,
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
        ],
        if (toggle != null)
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: AppSizes.iconSmall,
            color: AppColors.gold,
            semanticLabel: expanded ? BusStrings.collapse : BusStrings.expand,
          ),
      ],
    );

    // 콜백이 없으면 탭 대상도 아니다. `headerKey`도 함께 사라지므로 테스트가
    // 실수로 죽은 컨트롤을 두드리지 않는다.
    if (toggle == null) return row;
    return GestureDetector(
      key: headerKey,
      behavior: HitTestBehavior.opaque,
      onTap: toggle,
      child: row,
    );
  }

  /// `07:32 기준` — 캐시 신선도를 감추지 않고 고백한다.
  String? _stamp() {
    final at = view.fetchedAt;
    if (at == null) return null;
    final hhmm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return view.state == BusCardState.stale
        ? BusStrings.basedOnStale(hhmm)
        : BusStrings.basedOn(hhmm);
  }

  Widget _body() {
    if (!view.hasRows) {
      return BusEmptyState(
        state: view.state,
        onRetry: onRetry,
        onRegister: onRegister,
        retrying: retrying,
      );
    }
    return switch (style) {
      BusCardStyle.text => BusBodyText(view: view),
      BusCardStyle.axis => BusBodyAxis(view: view),
    };
  }

  Widget _flip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        key: flipKey,
        behavior: HitTestBehavior.opaque,
        onTap: onFlipDirection,
        child: Text(
          '${direction.otherLabel} ⌄',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
          ),
        ),
      ),
    );
  }
}
