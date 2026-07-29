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
    this.onRefresh,
    this.retrying = false,
  });

  static const headerKey = Key('bus_card_header');
  static const flipKey = Key('bus_card_flip');

  /// 새로고침 버튼. **제목줄 탭(접기)과 표적이 겹치므로 키로 찾는다** — 아이콘으로
  /// 찾으면 chevron·flip과 섞인다.
  static const refreshKey = Key('bus_card_refresh');

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

  /// 제목줄 새로고침. null이면 아이콘이 없다.
  ///
  /// **호스트는 여기에 `onRetry`와 같은 함수를 넘긴다.** 촉발 경로가 하나여야 in-flight
  /// 가드와 진행 표시가 어느 쪽에서 눌러도 같게 동작한다 — 두 경로로 갈리면 탭 N번이
  /// 동시 요청 N건이 되는 함정이 한쪽에만 남는다.
  final VoidCallback? onRefresh;

  /// 조회가 비행 중인가 — [BusEmptyState]와 제목줄 새로고침이 함께 본다.
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
          _header(),
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

  /// 새로고침 아이콘, 조회 중이면 진행 표시.
  ///
  /// 진행 표시가 **아이콘과 같은 크기**여야 한다 — 다르면 누를 때마다 제목줄의
  /// 오른쪽 요소들이 흔들린다.
  Widget _refreshControl() {
    if (retrying) {
      return SizedBox(
        width: AppSizes.iconSmall,
        height: AppSizes.iconSmall,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.gold,
        ),
      );
    }
    return GestureDetector(
      key: refreshKey,
      behavior: HitTestBehavior.opaque,
      onTap: onRefresh,
      child: Icon(
        Icons.refresh,
        size: AppSizes.iconSmall,
        color: AppColors.gold,
        semanticLabel: BusStrings.refresh,
      ),
    );
  }

  Widget _header() {
    final toggle = onToggleExpanded;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // 이모지만 글자보다 크게 그린다 — 한 `Text`에 담으면 이모지가 13px에 묶여
        // 작게 보이고, 집·학교를 한눈에 구별하는 것이 이 라벨의 일이다.
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: direction.emoji,
              style: const TextStyle(fontSize: BusStrings.headerEmojiSize),
            ),
            const TextSpan(text: ' '),
            TextSpan(text: direction.title),
          ]),
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
              BusStrings.stopSegment(stopName),
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
        // **펼친 상태에서만** 새로고침을 준다. 접히면 폴링이 멈추고 목록도 안 보여서
        // 눌러도 결과를 확인할 수 없다 — 기준시각을 접힘에서 숨기는 것과 같은 이유다.
        if (expanded && onRefresh != null) ...[
          _refreshControl(),
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
    // 새로고침은 제목줄 안에 있는데 제목줄 전체가 접기 표적이다. 안쪽
    // `GestureDetector`가 히트 테스트를 먼저 먹으므로 새로고침을 눌러도 접히지 않는다.
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
          BusStrings.flip(direction.otherLabel),
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
