import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/next_bus.dart';
import 'bus_more_count.dart';

/// `시간 축` 본문 — 0~15분 축에 버스를 점으로 놓는다.
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
  static Key dotKey(String routeId) => ValueKey('bus_axis_dot_$routeId');
  static Key labelKey(String routeId) => ValueKey('bus_axis_label_$routeId');

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
  static const labelWidth = 34.0;

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
        // 눈금(`지금 · 5분 · 10분 · 15분`)은 **눈으로만** 읽는 좌표계다. 스크린리더가
        // 이것까지 읽으면 라벨의 실제 도착 시각과 섞여 숫자가 두 배로 들린다.
        ExcludeSemantics(child: _scale()),
        const SizedBox(height: 2),
        SizedBox(height: 14, child: _rail()),
        const SizedBox(height: 2),
        SizedBox(height: 15, child: _labels()),
        // **라벨 행(Stack) 안에 우측 정렬로 넣지 않는다.** 15분을 넘긴 버스의 라벨은
        // `dotPosition`이 0.97로 clamp해 오른쪽 끝에 고정되는데, 상한이 걸릴 만큼
        // 노선이 많은 정류장에서는 보이는 3개 중 하나가 15분 이상인 일이 흔하다
        // (예: 18·20·22분) — 겹치면 감추려던 정보가 또 안 읽힌다. 별 줄로 둔다.
        if (view.hiddenCount > 0) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: BusMoreCount(hiddenCount: view.hiddenCount),
          ),
        ],
        // **`간단히`와 같은 함수로 판정한다.** 한쪽에만 두면 모양을 바꾼 사용자만
        // 조용히 정보를 덜 받는다.
        //
        // 축 위에 속 빈 점으로 그리는 안이 더 축답지만, 15분을 넘긴 2차가 오른쪽
        // 끝에 clamp돼 `N개 더`와 자리를 다투고 레이블 없이는 "다음 차"로 읽히지도
        // 않는다. 글자 한 줄이 정보 동등성을 확실히 지킨다.
        //
        // `hiddenCount`와 동시에 뜨지 않는다 — 감춘 개수가 있으려면 보이는 것이
        // 상한(3)만큼 있어야 하는데, 이 줄은 한 대일 때만 붙는다.
        if (nextBusMinutes(view) case final next?) ...[
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
              top: 6,
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
          top: 4,
          child: Container(
            width: 1,
            height: 6,
            color: AppColors.busSignalOff,
          ),
        ),
    ];
  }

  Widget _dot(BusArrival arrival, double width) {
    const size = 12.0;
    // **`AnimatedPositioned` + `ValueKey(routeId)`가 짝이다.** 키가 없으면 Flutter가
    // Stack 자식을 순서로 매칭해, 정렬이 바뀌는 순간 A 노선의 점이 B의 자리로
    // 미끄러진다(색까지 함께 건너간다).
    return AnimatedPositioned(
      key: dotKey(arrival.routeId),
      duration: tick,
      // 등속이어야 흐름으로 읽힌다 — ease를 쓰면 1초마다 가속·감속해 떨린다.
      curve: Curves.linear,
      left: (dotPosition(arrival.arrSec) * width) - (size / 2),
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
            return AnimatedPositioned(
              // 점과 같은 규칙으로 움직여야 라벨이 점을 따라간다.
              key: labelKey(a.routeId),
              duration: tick,
              curve: Curves.linear,
              left: (dotPosition(a.arrSec) * width) - labelWidth / 2,
              top: 0,
              width: labelWidth,
              // **도착 시각을 라벨에 실어 준다.** 이 모양은 분을 화면 위치로만
              // 인코딩하므로(점은 색뿐이고 라벨은 노선번호뿐이다) 감싸지 않으면
              // 스크린리더에는 `720`·`150`이 맥락 없이 읽혀 정보가 0이 된다 —
              // `간단히`가 `720번` + `2분`을 읽어 주는 것과 같은 사실을 말해야 한다.
              // 문구는 `간단히`와 **같은 상수**를 쓴다(두 모양이 갈라지지 않게).
              // 목록의 중요 ★를 `Semantics`로 감싼 것과 같은 수법이다.
              child: Semantics(
                label: '${BusStrings.routeLabel(a.routeNo)} '
                    '${a.arrMin == 0 ? BusStrings.arrivingNow : BusStrings.minutes(a.arrMin)}',
                excludeSemantics: true,
                // **박스를 넓히는 것만으로는 부족하다.** 사용자가 iOS 글자 크기를
                // 키우면 11pt가 그만큼 커져 34pt도 넘는다 — `scaleDown`은 그때
                // 잘리는 대신 줄인다. 하이픈이 붙은 긴 번호(실측 `1006-1` 36.8pt)도
                // 여기서 흡수된다.
                //
                // `softWrap: false`가 필요하다 — FittedBox는 자식에게 무한 폭을
                // 주므로 줄바꿈이 허용되면 긴 번호가 두 줄로 눕는다.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    a.routeNo,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: urgent ? AppColors.ink : AppColors.sub,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
