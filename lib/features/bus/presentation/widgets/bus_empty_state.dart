import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_card_view.dart';

/// 실패 계약의 비정상 상태 문구 (스펙 §3).
///
/// 네 상태가 **서로 다르게 읽혀야 한다.** 막차 끝남과 앱 고장을 같은 문구로
/// 뭉개면 사용자가 정류장에서 기다릴지 택시를 부를지 판단할 수 없다.
class BusEmptyState extends StatelessWidget {
  const BusEmptyState({
    super.key,
    required this.state,
    this.onRetry,
    this.onRegister,
    this.retrying = false,
  });

  final BusCardState state;
  final VoidCallback? onRetry;
  final VoidCallback? onRegister;

  /// `다시 시도`로 시작한 조회가 아직 비행 중인가.
  ///
  /// true면 그 자리에 진행 문구를 놓고 탭을 뗀다. 조회는 최대 10초 걸리는데 그동안
  /// 화면이 안 바뀌면 사용자는 버튼이 안 먹은 줄 알고 다시 누르고, 실패는 캐시되지
  /// 않으므로 **탭 N번 = 동시 HTTP 요청 N건**이 된다.
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    // **와일드카드를 두지 않는다.** `_ => emptyClosed`로 두면 `stale`(갱신 실패)이
    // 막차 문구로 뭉개진다 — 조회 실패 + 캐시 있음인데 사용자의 routeIds로 걸러
    // visible이 비면 state는 `stale`로 남고, 그때 제목줄은 `07:32 기준 · 갱신 실패`를
    // 붉게 쓰면서 본문은 `오늘 운행이 끝났어요`라고 단정하는 자기모순 카드가 된다.
    // 스펙 §3과 커밋된 buildBusCardView가 정면으로 금지한 것이다.
    //
    // `ok`는 **조회 전에만** 도달한다 — 조회 후에는 buildBusCardView가 `ok` + 빈 목록을
    // `closed`로 바꾸므로 이 분기로 오지 않는다. 그래서 로딩 문구가 맞다.
    final (title, hint, action, onAction) = switch (state) {
      BusCardState.ok => (BusStrings.emptyLoading, null, null, null),
      BusCardState.closed => (BusStrings.emptyClosed, null, null, null),
      // 막차 종료(closed)와 **다른 문구**를 쓴다 — 정류장에 다른 버스가 오는 상황이라
      // 사용자의 다음 행동이 정반대다. 노선을 바꾸는 경로는 확인 시트뿐이므로
      // 액션 대신 힌트로 안내한다.
      BusCardState.filteredOut => (
          BusStrings.emptyFiltered,
          BusStrings.emptyFilteredHint,
          null,
          null,
        ),
      // stale이 빈 목록으로 여기까지 오면 갱신 실패와 구분할 정보가 없다 —
      // down과 같은 문구를 **의도적으로** 공유한다(와일드카드가 아니라 이름을 둘 다 적는다).
      // 비행 중이면 라벨을 진행 문구로 바꾸고 콜백을 뗀다. **문구만 바꾸고 콜백을
      // 남기면 안 된다** — 리빌드가 오기 전에 도착한 탭이 그대로 요청을 만든다.
      // (호스트의 `_retrying` 가드가 그 창까지 막지만, 두 겹을 함께 둔다.)
      BusCardState.stale || BusCardState.down => (
          BusStrings.emptyDown,
          null,
          retrying ? BusStrings.emptyDownRetrying : BusStrings.emptyDownAction,
          retrying ? null : onRetry,
        ),
      BusCardState.keyError => (
          BusStrings.emptyKey,
          BusStrings.emptyKeyHint,
          null,
          null,
        ),
      BusCardState.noStop => (
          BusStrings.emptyNoStop,
          null,
          BusStrings.emptyNoStopAction,
          onRegister,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: AppColors.sub,
            ),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: AppSizes.spacing4),
          // **콜백이 없으면 탭 대상도 아니다.** 골드는 이 카드 안에서 행동을 뜻하고
          // `GestureDetector`는 누를 수 있다는 신호이므로, 둘 다 떼어 진행 문구가
          // 링크로 보이지 않게 한다 — `bus_arrival_card._header()`가
          // `onToggleExpanded == null`에서 chevron과 탭을 함께 빼는 것과 같은 규칙이다.
          if (onAction == null)
            Text(
              action,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.sub,
              ),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Text(
                action,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
