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
    this.refreshEnabled = true,
  });

  static const headerKey = Key('bus_card_header');
  static const flipKey = Key('bus_card_flip');

  /// 새로고침 버튼. 아이콘으로 찾으면 chevron·flip과 섞이므로 키로 찾는다.
  static const refreshKey = Key('bus_card_refresh');

  /// 정류장 등록 알약. 하단 행 오른쪽에서 새로고침과 자리를 나눠 쓴다.
  static const registerKey = Key('bus_card_register');

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

  /// 하단 행의 새로고침. null이면 아이콘이 없다.
  ///
  /// **호스트는 여기에 `onRetry`와 같은 함수를 넘긴다.** 촉발 경로가 하나여야 in-flight
  /// 가드와 진행 표시가 어느 쪽에서 눌러도 같게 동작한다 — 두 경로로 갈리면 탭 N번이
  /// 동시 요청 N건이 되는 함정이 한쪽에만 남는다.
  final VoidCallback? onRefresh;

  /// 조회가 비행 중인가 — [BusEmptyState]와 새로고침 아이콘이 함께 본다.
  final bool retrying;

  /// 지금 새로고침을 누를 수 있는가. false면 **자리는 지키되** 흐리고 눌리지 않는다.
  ///
  /// **아이콘을 없애지 않는 이유**: 사라졌다 나타나면 그 자리가 빈 칸이 되어 "고장난
  /// 것"으로 읽히고, 쿨다운이라는 이유를 말할 수단도 없어진다. 흐린 색이 이유다.
  final bool refreshEnabled;

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
            _bottomRow(),
          ],
        ],
      ),
    );
  }

  /// 새로고침 탭 영역을 아이콘보다 넓히는 여백. 16pt 아이콘 + 이 여백 = **40×32**.
  ///
  /// 하단 행은 접기 표적이 아니고 우측이 비어 있어 넉넉히 줄 수 있다 — 제목줄에
  /// 있을 때는 chevron과 붙어 있어 이만큼 못 줬다(`_bottomRow` 문서 참고).
  /// Apple 권장 44pt에는 조금 못 미치지만, 세로로 분리돼 있어 오탭의 대가가
  /// "아무 일도 안 일어남"이지 "카드가 접힘"이 아니다.
  static const _refreshHitPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  /// 새로고침 아이콘, 조회 중이면 진행 표시.
  ///
  /// 세 상태(진행·활성·쿨다운)가 **같은 자리·같은 크기**를 차지해야 한다 — 다르면
  /// 누를 때마다 하단 행의 요소가 흔들려 표적이 움직인다.
  Widget _refreshControl() {
    if (retrying) {
      return Padding(
        padding: _refreshHitPadding,
        child: SizedBox(
          width: AppSizes.iconSmall,
          height: AppSizes.iconSmall,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gold,
          ),
        ),
      );
    }

    final icon = Padding(
      padding: _refreshHitPadding,
      child: Icon(
        Icons.refresh,
        size: AppSizes.iconSmall,
        // 쿨다운이면 흐리게 — 누를 수 없다는 것을 색으로 말한다.
        color: refreshEnabled ? AppColors.gold : AppColors.faint,
        semanticLabel: BusStrings.refresh,
      ),
    );

    return GestureDetector(
      key: refreshKey,
      behavior: HitTestBehavior.opaque,
      // 쿨다운이면 `null` — 하단 행에는 조상 제스처가 없으므로 흡수용 빈 콜백이
      // 필요 없다(제목줄에 있을 때는 필요했다: 인식기가 없으면 제목줄 탭이 아레나를
      // 이겨 카드가 접혔다). 눌러도 아무 일이 없고 흐린 색이 이유를 말한다.
      onTap: refreshEnabled ? onRefresh : null,
      child: icon,
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
    // 제목줄에는 다른 표적을 두지 않는다 — 새로고침은 하단 행으로 내렸다
    // (`_bottomRow` 문서 참고).
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
        retrying: retrying,
      );
    }
    return switch (style) {
      BusCardStyle.text => BusBodyText(view: view),
      BusCardStyle.axis => BusBodyAxis(view: view),
    };
  }

  /// 하단 조작 행 — 좌: 방향 전환, 우: 새로고침.
  ///
  /// **새로고침이 제목줄이 아니라 여기 있는 이유**: 제목줄 **전체**가 접기 표적이라,
  /// 그 안에 16pt 아이콘을 두면 빗나가는 순간 카드가 접힌다(실기기 신고 2026-07-29:
  /// "접는거랑 새로고침이 가까워서 손가락이 굵은 사람은 실수로 누르게 돼").
  /// 히트 영역을 넓히는 것은 확률만 낮춘다 — 표적이 표적을 감싸는 구조는 그대로다.
  ///
  /// 여기로 내리면 그 구조가 사라진다: 제목줄은 순수하게 접기이고, 이 행은 접기
  /// 표적이 아니므로 오탭해도 접히지 않는다. 본문 높이만큼 세로로 떨어져 있어
  /// 손가락이 두 표적을 동시에 덮을 수 없고, 공간이 넉넉해 히트 영역도 크게 준다.
  Widget _bottomRow() {
    return Row(
      children: [
        _flipControl(),
        const Spacer(),
        // **등록과 새로고침은 함께 나오지 않는다.** 호스트가 정류장 미등록 카드에는
        // `onRefresh`를, 그 밖에는 `onRegister`를 넘기지 않는다(조회할 정류장이
        // 없으면 새로고침할 것도 없다). 그래도 둘을 같은 자리에 두므로 순서를
        // 명시해 두 표적이 겹치는 구성을 만들 수 없게 한다 — 가드가 이 배타성을 잡는다.
        if (onRegister != null)
          _registerControl()
        else if (onRefresh != null)
          _refreshControl(),
      ],
    );
  }

  /// 하단 알약의 최소 높이. **패딩으로 높이를 만들지 않는다** — 글꼴 크기가
  /// 다른 두 알약(12·13px)이 서로 다른 높이가 되고, 실제로 방향 전환이 39dp로
  /// 1dp 모자랐다. 최소 높이를 못박으면 둘이 같아지고 Apple 권장 44pt를 만족한다.
  static const _pillMinHeight = 44.0;

  /// 방향 전환 — **보조 동작**이라 테두리만 두른 중립색 알약이다.
  ///
  /// 맨 텍스트였을 때는 히트 영역이 글자 높이(약 18dp)뿐이라 "눌렀는데 반응이
  /// 없다"가 났다(실기기 신고 2026-08-07). 세로 패딩으로 40dp를 확보한다.
  Widget _flipControl() {
    return GestureDetector(
      key: flipKey,
      behavior: HitTestBehavior.opaque,
      onTap: onFlipDirection,
      child: Container(
        constraints: const BoxConstraints(minHeight: _pillMinHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Text(
          BusStrings.flip(direction.otherLabel),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.sub,
          ),
        ),
      ),
    );
  }

  /// 정류장 등록 — **이 카드가 존재하는 이유**라 골드 채움 알약으로 무게를 준다.
  ///
  /// 방향 전환과 **모양·무게를 다르게** 둔다. 둘 다 같은 알약이면 보조 동작이 주
  /// 동작만큼 중요해 보여, 처음 쓰는 사람이 무엇을 눌러야 할지 한 번 더 생각한다.
  ///
  /// 채움은 `goldFill` + `onGold`다 — 라이트에서 `gold`(딥골드) 채움 위 글자는
  /// 대비가 낮다(세그먼트·배지와 같은 규칙).
  Widget _registerControl() {
    return GestureDetector(
      key: registerKey,
      behavior: HitTestBehavior.opaque,
      onTap: onRegister,
      child: Container(
        constraints: const BoxConstraints(minHeight: _pillMinHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.goldFill,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Text(
          BusStrings.emptyNoStopAction,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onGold,
          ),
        ),
      ),
    );
  }
}
