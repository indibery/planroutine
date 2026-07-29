import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/bus_route.dart';
import '../../domain/bus_stop.dart';
import '../../domain/commute_direction.dart';

/// 저장 직전 확인 — 방향이 조용히 틀리는 것을 막는다.
///
/// 실측: `수원시청.수원일자리센터`가 `GGB201000156`과 `GGB202000003` 두 개이고
/// 좌표 차이는 약 60m다. 이름으로도 좌표로도 사람이 고를 수 없지만 **자기가 타는
/// 버스 번호는 안다.** 잘못 고르면 화면에는 버스가 정상적으로 뜨는데 전부 반대
/// 방향이라, 사용자는 앱이 고장 났다고 생각하지 않고 자기가 늦었다고 생각한다.
///
/// `screens/`가 아니라 `widgets/`에 산다 — `EventEditDialog`·`ConfirmDialog`와 같은
/// 형태(public 위젯 + `static show`)이고, 시트만 고치는 커밋이 화면 diff에 섞이지
/// 않아야 한다.
class BusStopConfirmSheet extends StatefulWidget {
  const BusStopConfirmSheet({
    super.key,
    required this.stop,
    required this.routes,
    required this.arrivals,
    required this.state,
    required this.slot,
  });

  /// `맞아요` 버튼. **키를 시트가 들고 있다** — 화면 클래스에 두면 시트를 다른
  /// 진입점에서 띄울 때 테스트가 관계없는 화면을 import하게 된다.
  static const acceptKey = Key('bus_confirm_accept');

  final BusStop stop;

  /// 이 정류장을 지나는 노선 전체 — **선택 목록의 주 재료다.**
  ///
  /// 도착정보를 목록으로 쓰던 시절에는 등록하는 **시각**이 고를 수 있는 노선을
  /// 결정했다. 군포 장미아파트는 경유노선이 10개인데 그 순간 도착정보가 있는 것은
  /// 8개였고, 사용자 실기기에서는 2개만 보였다 — 자기 버스가 목록에 없으면 노선을
  /// 좁힐 방법이 없다. 경유노선은 도착 여부와 무관하므로 심야에 등록해도 같은
  /// 목록이 나온다.
  ///
  /// 비면 [arrivals]로 목록을 만든다(비경기 정류장·경유노선 조회 실패).
  /// 그 폴백은 [buildRouteChoices]가 든다.
  final List<BusRoute> routes;

  /// 지금 오는 버스. **목록이 아니라 목록의 장식이다** — 각 행에 남은 분을 붙인다.
  ///
  /// [routes]가 비었을 때만 목록 자체의 재료가 된다.
  final List<BusArrival> arrivals;

  /// 저장 대상 슬롯. **required다** — 옵션으로 두면 문구를 빼먹은 호출부가 조용히
  /// 생기는데, 이 시트가 저장 직전 마지막 화면이라 그때는 알릴 방법이 없다.
  ///
  /// 카드에서 들어오면 슬롯이 시계로 결정되므로(기본 시간대에서 08:31–15:59는
  /// 도착지) 사용자가 알 수 있는 곳이 제목줄과 이 줄뿐이다.
  final CommuteDirection slot;

  /// **도착정보** 조회 결과 상태. 경유노선 조회와는 별개 호출이다.
  ///
  /// 빈 목록의 이유를 구분하는 데 쓴다. 목록이 비는 경로는 두 가지고 뜻이 정반대다:
  /// 막차 후처럼 **정말 안 오는 경우**(`ok`·`closed`)와 네트워크·키 문제로 **못
  /// 물어본 경우**(`down`·`keyError`). 뭉개면 조회 실패 순간 사용자는 "이 정류장에
  /// 오는 버스가 없어요"를 읽고 방향을 전혀 확인하지 못한 채 저장한다.
  final BusCardState state;

  static Future<BusStop?> show(
    BuildContext context, {
    required BusStop stop,
    required List<BusRoute> routes,
    required List<BusArrival> arrivals,
    required BusCardState state,
    required CommuteDirection slot,
  }) {
    return showModalBottomSheet<BusStop>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BusStopConfirmSheet(
        stop: stop,
        routes: routes,
        arrivals: arrivals,
        state: state,
        slot: slot,
      ),
    );
  }

  @override
  State<BusStopConfirmSheet> createState() => _BusStopConfirmSheetState();
}

class _BusStopConfirmSheetState extends State<BusStopConfirmSheet> {
  /// 그릴 선택 목록. 노선 순서·행선지·남은 분이 여기서 한 번에 결정된다.
  late final List<BusRouteChoice> _choices;

  late Set<String> _checked;

  /// 전부 해제한 채 `맞아요`를 눌렀는가 — 시트 **안에** 경고를 띄운다.
  ///
  /// 스낵바를 쓰지 않는다. `ScaffoldMessenger`는 루트 Scaffold에 그리는데 시트는 그
  /// 위에 푸시된 라우트라, 스낵바가 시트와 scrim에 정확히 덮여 보이지 않는다 —
  /// 저장은 막혔는데 아무 일도 없는 것처럼 읽혀 `맞아요`가 죽은 버튼이 된다.
  /// 시트 안에서 벌어진 일은 시트 안에서 말한다.
  bool _needRoute = false;

  /// **도착정보**를 못 물어봤는가. 경유노선과 별개 호출이라 이것만 실패할 수 있다.
  bool get _arrivalsFailed =>
      widget.state == BusCardState.down || widget.state == BusCardState.keyError;

  /// 확인할 재료가 하나도 없는가 — **이때만 저장을 막는다.**
  ///
  /// 예전에는 도착 조회 실패만으로 막았다. 경유노선이 들어온 뒤로는 도착 시간이
  /// 없어도 행선지로 방향을 확인할 수 있으므로, 그것만으로 막으면 확인할 수 있는
  /// 사람을 막는 것이 된다. 반대로 **둘 다** 없으면 시트가 통과 도장이 되므로
  /// 그때는 막는다 — 시트를 만든 이유가 실패 경로에서 무너지지 않게.
  bool get _blocked => _choices.isEmpty && _arrivalsFailed;

  @override
  void initState() {
    super.initState();
    _choices = buildRouteChoices(
      routes: widget.routes,
      arrivals: widget.arrivals,
    );
    // 기본은 전부 체크 — 방향만 확인하려는 사람이 `맞아요`만 눌러도 되게.
    _checked = _choices.map((c) => c.routeId).toSet();
  }

  void _accept() {
    if (_choices.isNotEmpty && _checked.isEmpty) {
      setState(() => _needRoute = true);
      return;
    }

    // 전부 체크된 상태는 **빈 집합**으로 저장한다. 열거해 저장하면 "전부"가
    // "이 열 개"로 굳어 노선이 신설됐을 때 영구히 안 보인다.
    final selected =
        _checked.length == _choices.length ? <String>{} : _checked;

    Navigator.of(context).pop(widget.stop.copyWith(routeIds: selected));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(BusStrings.confirmTitle, style: AppTextStyles.heading),
            const SizedBox(height: AppSizes.spacing8),
            Text(
              '${widget.stop.nodeNm}  ${widget.stop.nodeNo}',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSizes.spacing4),
            // 이 정류장이 **어느 슬롯으로** 가는지. 시트는 nodeId 방향(상행/하행)만
            // 확인시키고 슬롯 방향(출발지/도착지)은 말하지 않아, 일과시간에 카드에서
            // 들어온 사용자가 집 앞 정류장을 도착지에 넣고도 알지 못했다.
            Text(
              BusStrings.savesTo(widget.slot.slotLabel),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: AppColors.sub,
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            if (_choices.isEmpty)
              // 목록이 없는 이유를 갈라 말한다. 못 물어본 경우에는 카드의 실패
              // 문구를 그대로 쓴다 — 시트용 문구를 따로 만들면 사용자가 읽는
              // 사실이 같은데 둘 중 하나만 손보게 된다.
              _note(_arrivalsFailed
                  ? (widget.state == BusCardState.keyError
                      ? BusStrings.emptyKey
                      : BusStrings.emptyDown)
                  : BusStrings.confirmNoRoutes)
            else ...[
              // 시트 안에서 사용자가 할 일을 말하는 **유일한 지시문**이다.
              // eyebrow(10px·자간 2.5·골드)로 그리면 본문보다 작아 장식 라벨로
              // 읽히고, 방향 확인이라는 이 시트의 존재 이유가 가장 약한 위계에 놓인다.
              Text(BusStrings.confirmRoutesTitle, style: AppTextStyles.bodyL),
              // 노선은 받았는데 도착 시간만 못 받은 경우. 목록은 그대로 쓸 수 있고
              // 방향은 행선지로 확인하면 되므로 막지 않고 이유만 밝힌다 —
              // 시간이 통째로 빈 목록에 설명이 없으면 목록이 깨진 것으로 읽힌다.
              if (_arrivalsFailed) _note(BusStrings.confirmNoArrivalTimes),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _choices.map(_routeTile).toList(),
                ),
              ),
            ],
            if (_needRoute)
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.spacing8),
                child: Text(
                  BusStrings.confirmNeedRoute,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkRed,
                  ),
                ),
              ),
            const SizedBox(height: AppSizes.spacing16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(BusStrings.confirmReject),
                  ),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: ElevatedButton(
                    key: BusStopConfirmSheet.acceptKey,
                    // 재료가 하나도 없으면 저장할 수 없다 — 방향을 확인할 수 없는데
                    // 저장을 허용하면 시트가 통과 도장이 된다. 사용자는 `아니에요`로
                    // 닫고 다시 고르면 그때 새로 조회한다.
                    onPressed: _blocked ? null : _accept,
                    child: const Text(BusStrings.confirmAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(String message) {
    return Text(
      message,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        color: AppColors.sub,
      ),
    );
  }

  Widget _routeTile(BusRouteChoice choice) {
    final arrMin = choice.arrMin;
    final dest = choice.route.destName;

    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: _checked.contains(choice.routeId),
      onChanged: (on) => setState(() {
        if (on ?? false) {
          _checked.add(choice.routeId);
          // 하나라도 다시 켜졌으면 경고를 내린다 — 이미 고친 것을 계속 꾸짖지 않는다.
          _needRoute = false;
        } else {
          _checked.remove(choice.routeId);
        }
      }),
      title: Text(BusStrings.routeLabel(choice.route.routeNo)),
      // 행선지가 방향을 가르는 단서다 — 길 양쪽 정류장은 이름도 번호도 같지만
      // 행선지는 다르다. 도착정보 폴백 경로에는 행선지가 없어 그때만 빠진다.
      subtitle: dest.isEmpty
          ? null
          : Text(
              BusStrings.routeDest(dest),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: AppColors.sub,
              ),
            ),
      // 도착 정보가 없는 노선은 이 자리를 비운다. `곧 도착`(0분)과 `정보 없음`(null)은
      // 다르다 — 뭉개면 심야에 등록하는 사용자에게 전부 `곧 도착`으로 보인다.
      secondary: arrMin == null
          ? null
          : Text(
              arrMin == 0
                  ? BusStrings.arrivingNow
                  : BusStrings.minutesLater(arrMin),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: AppColors.sub,
              ),
            ),
    );
  }
}
