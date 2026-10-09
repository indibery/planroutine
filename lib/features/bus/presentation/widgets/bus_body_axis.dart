import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/arrival_text.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/axis_label_layout.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/next_bus.dart';
import 'bus_more_count.dart';
import 'bus_signal_color.dart';

/// `시간 축` 본문 — 0~15분 축에 버스를 버스 모양 표시로 놓는다.
///
/// 표시 아래 라벨은 `노선번호 분`이고 **초는 쓰지 않는다**(사용자 결정 2026-10-09 —
/// 초는 `간단히`만 쓴다). 라벨은 도착 순으로 **두 줄에 번갈아** 놓아, 가까운 두 대가
/// 한 줄에서 서로를 밀어내지 않게 한다. 아래에 임박도 범례를 둔다.
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

  /// 점이 한 걸음 움직이는 시간. 호스트의 1초 틱과 **같아야** 이어져 보인다 —
  /// 짧으면 움직였다 멈추기를 반복하고, 길면 다음 틱이 애니메이션을 자른다.
  static const tick = Duration(seconds: 1);

  static const _minFraction = 0.03;
  static const _maxFraction = 0.97;

  /// 점·라벨을 찾는 키. **둘을 다른 이름으로 둔다** — 같은 `routeId`로 겹치면
  /// `find.byKey`가 둘을 함께 물어 테스트가 어느 쪽을 재는지 알 수 없다.
  ///
  /// 위치 기반 finder(`find.byType(Container).at(1)`)를 대신한다. 보조 눈금이
  /// 들어오면서 그 인덱스가 밀렸다 — 레일·눈금·점이 모두 `Container`다.
  /// **차량 기준 키.** 점의 정체성은 노선이 아니라 "지금 오고 있는 이 버스"다.
  ///
  /// 노선으로 묶으면 앞차가 지나가는 순간 같은 위젯의 위치만 0분 → 8분으로 바뀌어
  /// **점이 시간을 거슬러 오른쪽으로 미끄러진다**(실기기 신고 2026-07-30).
  /// 차량으로 묶으면 지나간 차는 키가 사라져 제거되고, 뒤차는 **같은 키를 유지한 채**
  /// 속 빈 점에서 채운 점으로 바뀌며 제자리에 남는다.
  ///
  /// **점과 다음 점이 같은 이름공간을 쓴다** — 달랐다면 뒤차가 1차가 될 때 위젯이
  /// 교체돼 그 자리에서 채워지는 대신 사라졌다 다시 생긴다.
  static Key dotKeyFor(String id) => ValueKey('bus_axis_dot_$id');
  static Key labelKeyFor(String id) => ValueKey('bus_axis_label_$id');

  /// 차량 식별자가 없으면(TAGO) 노선으로 떨어진다. 그 경로에서는 뒤로 미끄러지는
  /// 증상이 남는다 — 수도권은 GBIS라 주 경로는 고쳐진다.
  static String _idOf(BusArrival a) => a.vehicleId ?? a.routeId;
  static String _nextIdOf(BusArrival a) => a.vehicleId2 ?? '${a.routeId}_next';

  /// 노선번호 라벨 박스의 폭.
  ///
  /// **`left`의 `- labelWidth / 2`와 짝이다** — 하나만 고치면 라벨이 점에서 어긋난다
  /// (예전에는 `28`과 `14`가 따로 박혀 있었다).
  ///
  /// 28pt였을 때 **4자리 노선번호가 잘렸다**(실기기 신고 2026-07-29: `5623` → `562`).
  /// 실측 폭은 `3030` 28.6pt · `5623` 27.7pt로 28pt 경계에 걸쳐 있었고, 0.3pt 여유는
  /// 폰트 버전·힌팅·글자 크기 설정 하나에 먹혔다. **0.3pt는 여유가 아니다.**
  ///
  /// 34pt면 4자리 최대(28.6)에 5.4pt 여유가 생긴다. 라벨이 넓어져 인접 버스와 겹칠
  /// 확률이 21% 늘지만, **잘린 숫자는 읽기 어려운 것이 아니라 틀린 것**이다 —
  /// `562`도 존재할 수 있는 노선번호이고 사용자는 다른 버스를 보고 있다는 사실조차
  /// 알 수 없다. 겹침(읽기 어려움)보다 잘림(틀림)을 먼저 없앤다.
  ///
  /// **58pt로 넓혔다**(2026-10-09). 라벨에 분(`12분`)이 붙으면서 `5623 12분`이 약 52pt가
  /// 됐다. 라벨이 두 줄로 엇갈려 같은 줄의 이웃은 한 칸 건너라 넓혀도 덜 부딪힌다.
  static const labelWidth = 58.0;

  /// 라벨이 박스를 넘길 때 남겨야 할 여유. 가드가 이 값으로 검사한다.
  ///
  /// "들어간다"가 아니라 "여유가 있다"로 재는 이유가 위 버그다 — 0.3pt를 OK로 판정한
  /// 것이 실기기 잘림을 놓친 원인이었다.
  static const labelHeadroom = 3.0;

  final BusCardView view;

  /// 축 위 위치를 0~1로. **양 끝에서 점이 반쯤 잘리지 않게 clamp한다.**
  ///
  /// **초를 받는다.** 분을 받던 시절에는 `5분 59초`와 `6분 1초`가 같은 자리에 서고
  /// 30초 폴링마다 한 칸씩 튀었다(실기기 신고 2026-07-30).
  static double dotPosition(int arrSec) {
    final raw = arrSec / (axisRange * 60);
    return raw.clamp(_minFraction, _maxFraction);
  }

  static Color _dotColor(int arrMin) => busSignalColor(busSignalOf(arrMin));

  /// 라벨 한 줄의 높이. 두 줄이 엇갈린다.
  static const _labelRowHeight = 16.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 눈금(`지금 · 5분 · 10분 · 15분`)은 **눈으로만** 읽는 좌표계다. 스크린리더가
        // 이것까지 읽으면 라벨의 실제 도착 시각과 섞여 숫자가 두 배로 들린다.
        ExcludeSemantics(child: _scale()),
        const SizedBox(height: 2),
        SizedBox(height: 24, child: _rail()),
        const SizedBox(height: 2),
        SizedBox(height: _labelRowHeight * 2, child: _labels()),
        // 범례와 감춘 개수를 한 줄에 둔다. **라벨 행(Stack) 안에 넣지 않는다** — 15분을
        // 넘긴 라벨은 오른쪽 끝에 clamp돼 고정되므로, 라벨 행에 두면 겹쳐 감추려던 정보가
        // 또 안 읽힌다. 라벨 행 아래 별 줄이다.
        const SizedBox(height: 4),
        Row(
          children: [
            // 범례는 색의 뜻을 **눈으로** 읽게 하는 것이다. 스크린리더는 라벨에서 분을
            // 이미 듣는다.
            ExcludeSemantics(child: _legend()),
            const Spacer(),
            if (view.hiddenCount > 0)
              BusMoreCount(hiddenCount: view.hiddenCount),
          ],
        ),
        // **`간단히`와 같은 함수로 판정한다.** 한쪽에만 두면 모양을 바꾼 사용자만
        // 조용히 정보를 덜 받는다.
        //
        // 축 위에 속 빈 점으로 그리는 안이 더 축답지만, 15분을 넘긴 2차가 오른쪽
        // 끝에 clamp돼 `N개 더`와 자리를 다투고 레이블 없이는 "다음 차"로 읽히지도
        // 않는다. 글자 한 줄이 정보 동등성을 확실히 지킨다.
        //
        // `hiddenCount`와 동시에 뜨지 않는다 — 감춘 개수가 있으려면 보이는 것이
        // 상한(3)만큼 있어야 하는데, 이 줄은 한 대일 때만 붙는다.
        if (nextBusOffAxis(view) case final next?) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              BusStrings.nextBus(next),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                color: AppColors.faint,
              ),
            ),
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
              top: 11,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.busSignalOff,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ..._minorTicks(width),
            ...view.visible.map((a) => _dot(a, width)),
            if (nextBusOnAxis(view) case final sec?)
              _nextDot(sec, width, _nextIdOf(view.visible.single)),
          ],
        );
      },
    );
  }

  /// 1분 간격 보조 눈금.
  ///
  /// **라벨을 늘리지 않고 눈금만 깐다** — 글자를 1분마다 찍으면 노선 라벨
  /// (`labelWidth` 34pt)과 부딪힌다. 5분 라벨은 좌표를 말하고, 이 실선은 그 사이를
  /// 읽게 해 준다(실기기 요청 2026-07-30: "5분 단위보다 세밀하게").
  ///
  /// 양 끝(0분·15분)은 그리지 않는다 — 라벨이 이미 그 자리를 말하고, 끝에 세우면
  /// 레일의 둥근 마구리와 겹쳐 지저분해진다.
  List<Widget> _minorTicks(double width) {
    return [
      for (var m = 1; m < axisRange; m++)
        Positioned(
          left: (m / axisRange) * width,
          top: 9,
          child: Container(width: 1, height: 6, color: AppColors.busSignalOff),
        ),
    ];
  }

  Widget _dot(BusArrival arrival, double width) {
    const size = 20.0;
    // **`AnimatedPositioned` + 차량 키가 짝이다.** 키가 없으면 Flutter가 Stack 자식을
    // 순서로 매칭해, 정렬이 바뀌는 순간 A 노선의 표시가 B의 자리로 미끄러진다.
    return AnimatedPositioned(
      key: dotKeyFor(_idOf(arrival)),
      duration: tick,
      // 등속이어야 흐름으로 읽힌다 — ease를 쓰면 1초마다 가속·감속해 떨린다.
      curve: Curves.linear,
      left: (dotPosition(arrival.arrSec) * width) - (size / 2),
      top: 2,
      // **버스 모양 표시**(2026-10-09). 동그란 점은 가까운 두 대가 겹치면 하나로
      // 읽혔다. 둥근 네모 + 아이콘은 겹쳐도 테두리로 갈린다.
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: _dotColor(arrival.arrMin),
          // 화면 배경색 테두리로 레일·이웃 표시와 겹칠 때 형태를 지킨다. 카드 면
          // 토큰(`glass`)은 다크에서 반투명이라 테두리로 쓰면 레일이 비친다.
          border: Border.all(color: AppColors.background, width: 1.5),
        ),
        child: Icon(
          Icons.directions_bus,
          size: 12,
          color: AppColors.background,
        ),
      ),
    );
  }

  /// 그 다음 차 — **속 빈 점**. 채운 점(지금 오는 차)과 형태로 갈린다.
  ///
  /// 색으로 가르지 않는 이유: 채운 점은 남은 시간에 따라 빨강·노랑·초록이 되는데
  /// 다음 차까지 그 규칙을 쓰면 "2분 남은 다음 차"가 빨간 점이 돼 지금 오는 차보다
  /// 급해 보인다. 형태(속 빔)가 위계를 말하고 색은 중립으로 둔다.
  Widget _nextDot(int arrSec2, double width, String id) {
    const size = 16.0;
    return AnimatedPositioned(
      key: dotKeyFor(id),
      duration: tick,
      curve: Curves.linear,
      left: (dotPosition(arrSec2) * width) - (size / 2),
      top: 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.sub, width: 2),
        ),
      ),
    );
  }

  /// `● 3분 미만 ● 3~7분 ● 여유` — 색의 뜻. 칸 경계는 도메인 상수에서 받는다.
  Widget _legend() {
    Widget item(BusSignal signal, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: busSignalColor(signal),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 11,
            color: AppColors.sub,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 10,
      children: [
        item(BusSignal.near, BusStrings.legendUnder(busUrgentMinutes)),
        item(
          BusSignal.soon,
          BusStrings.legendRange(busUrgentMinutes, busSoonMinutes),
        ),
        item(BusSignal.far, BusStrings.legendFar),
      ],
    );
  }

  Widget _labels() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // **라벨을 한 목록으로 모아 도착 순으로 줄을 나눈다.** 따로 그리면 서로를 못
        // 보고 겹친다 — 실기기에서 1분·1.5분 두 대가 `55536023`으로 뭉쳐 읽혔다
        // (2026-07-30). 이웃한 두 라벨은 서로 다른 줄에 서고, 같은 줄 안에서만 민다.
        final entries = <_LabelSpec>[
          for (final a in view.visible)
            _LabelSpec(
              key: labelKeyFor(_idOf(a)),
              center: dotPosition(a.arrSec) * width,
              text: a.routeNo,
              minutes: a.arrMin == 0
                  ? BusStrings.axisArriving
                  : BusStrings.minutes(a.arrMin),
              semantics:
                  '${BusStrings.routeLabel(a.routeNo)} '
                  '${a.arrMin == 0 ? BusStrings.arrivingNow : BusStrings.minutes(a.arrMin)}',
              color: busSignalOf(a.arrMin) == BusSignal.near
                  ? AppColors.ink
                  : AppColors.sub,
              weight: FontWeight.w700,
            ),
          if (nextBusOnAxis(view) case final sec?)
            _LabelSpec(
              key: labelKeyFor(_nextIdOf(view.visible.single)),
              center: dotPosition(sec) * width,
              // **노선번호다.** 두 점 모두 같은 노선이므로 `다음`이라고 쓰면 축에서
              // 그 자리만 다른 규칙이 된다 — 어느 쪽이 먼저인지는 점의 형태가
              // 말한다(채움 = 먼저). 스크린리더에는 위치가 안 보이므로 풀어 준다.
              text: view.visible.single.routeNo,
              minutes: BusStrings.minutes((sec / 60).round()),
              semantics: BusStrings.nextBus((sec / 60).round()),
              color: AppColors.faint,
              weight: FontWeight.w600,
            ),
        ]..sort((a, b) => a.center.compareTo(b.center));

        // 짝수 번째는 윗줄, 홀수 번째는 아랫줄. 줄마다 따로 밀어 낸다.
        final xs = List<double>.filled(entries.length, 0);
        for (final row in [0, 1]) {
          final idx = [
            for (var i = row; i < entries.length; i += 2) i,
          ];
          final laid = layoutAxisLabels(
            [for (final i in idx) entries[i].center],
            labelWidth,
            width,
          );
          for (final (k, i) in idx.indexed) {
            xs[i] = laid[k];
          }
        }

        return Stack(
          children: [
            for (final (i, e) in entries.indexed)
              AnimatedPositioned(
                // 점과 같은 규칙으로 움직여야 라벨이 점을 따라간다.
                key: e.key,
                duration: tick,
                curve: Curves.linear,
                left: xs[i] - labelWidth / 2,
                top: (i % 2) * _labelRowHeight,
                width: labelWidth,
                // **도착 시각을 라벨에 실어 준다.** 이 모양은 분을 화면 위치로만
                // 인코딩하므로(점은 색뿐이고 라벨은 노선번호뿐이다) 감싸지 않으면
                // 스크린리더에는 `720`이 맥락 없이 읽혀 정보가 0이 된다.
                child: Semantics(
                  label: e.semantics,
                  excludeSemantics: true,
                  // **박스를 넓히는 것만으로는 부족하다.** iOS 글자 크기를 키우면
                  // 11pt가 그만큼 커져 34pt도 넘는다 — `scaleDown`이 잘리는 대신
                  // 줄인다. 하이픈이 붙은 긴 번호(실측 `1006-1` 36.8pt)도 흡수된다.
                  //
                  // `softWrap: false`가 필요하다 — FittedBox는 자식에게 무한 폭을
                  // 주므로 줄바꿈이 허용되면 긴 번호가 두 줄로 눕는다.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          e.text,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11,
                            fontWeight: e.weight,
                            color: e.color,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          e.minutes,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: e.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 라벨 한 개가 그려지는 데 필요한 것 전부. 밀어내기 계산과 렌더를 갈라 두려고 둔다.
class _LabelSpec {
  const _LabelSpec({
    required this.key,
    required this.center,
    required this.text,
    required this.minutes,
    required this.semantics,
    required this.color,
    required this.weight,
  });

  final Key key;

  /// 밀어내기 전, 점이 있는 진짜 x.
  final double center;
  final String text;

  /// 노선번호 옆의 `2분` / `곧`. 초는 쓰지 않는다.
  final String minutes;
  final String semantics;
  final Color color;
  final FontWeight weight;
}
