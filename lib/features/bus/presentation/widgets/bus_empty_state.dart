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
  });

  final BusCardState state;
  final VoidCallback? onRetry;
  final VoidCallback? onRegister;

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
      // stale이 빈 목록으로 여기까지 오면 갱신 실패와 구분할 정보가 없다 —
      // down과 같은 문구를 **의도적으로** 공유한다(와일드카드가 아니라 이름을 둘 다 적는다).
      BusCardState.stale || BusCardState.down => (
          BusStrings.emptyDown,
          null,
          BusStrings.emptyDownAction,
          onRetry,
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
