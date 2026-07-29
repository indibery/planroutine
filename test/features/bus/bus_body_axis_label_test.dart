import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';

/// 라벨 한 개의 실제 폭. 카드가 쓰는 것과 **같은 스타일**이어야 의미가 있다.
double _labelWidth(String routeNo) {
  final tp = TextPainter(
    text: TextSpan(
      text: routeNo,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return tp.width;
}

BusCardView _view(List<String> routeNos) => BusCardView(
      state: BusCardState.ok,
      visible: [
        for (final (i, no) in routeNos.indexed)
          BusArrival.fromMinutes(routeId: 'R$i', routeNo: no, arrMin: i * 5),
      ],
      hiddenCount: 0,
      fetchedAt: DateTime(2026, 7, 29, 19, 51),
    );

void main() {
  // **실측 Pretendard를 올린다.** `flutter test`의 기본 폴백 폰트는 모든 글자가 1em
  // 고정폭이라 같은 문자열을 1.76배 넓게 잡는다 — 이 파일의 모든 수치가 무의미해진다.
  setUpAll(() async {
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/PretendardVariable.ttf'));
    await loader.load();
  });

  group('시간 축 노선번호 라벨 — 잘리면 틀린 정보가 된다', () {
    // 실기기 신고(2026-07-29): `5623`이 `562`로 잘렸다. 박스가 28pt였고 실측 폭이
    // 27.7pt로 **0.3pt 여유**였다 — 폰트 버전·힌팅·글자 크기 설정 하나가 그만큼을
    // 먹는다. 스크린샷으로는 못 잡았고 숫자로 재야 잡힌다.
    //
    // 그래서 "들어간다"가 아니라 **"여유가 있다"** 로 검사한다.
    test('4자리 노선번호가 박스에 여유를 두고 들어간다', () {
      // 실측 경기 노선번호들. `3030`이 가장 넓다(28.6pt).
      const fourDigit = ['3030', '5623', '6501', '1102', '9711'];

      for (final no in fourDigit) {
        final w = _labelWidth(no);
        expect(
          w,
          lessThanOrEqualTo(
            BusBodyAxis.labelWidth - BusBodyAxis.labelHeadroom,
          ),
          reason: '$no 라벨 ${w.toStringAsFixed(1)}pt — 박스 '
              '${BusBodyAxis.labelWidth}pt에 여유 '
              '${BusBodyAxis.labelHeadroom}pt를 남기지 못한다',
        );
      }
    });

    test('짧은 번호는 당연히 들어간다 — 회귀 대조군', () {
      for (final no in ['9', '15', '87', '541', '11-5']) {
        expect(_labelWidth(no),
            lessThanOrEqualTo(BusBodyAxis.labelWidth - BusBodyAxis.labelHeadroom));
      }
    });

    testWidgets('라벨 박스 폭과 중앙 정렬 오프셋이 짝이다', (tester) async {
      // `width: 28`과 `left: - 14`가 따로 박혀 있던 시절에는 한쪽만 고치면 라벨이
      // 점에서 조용히 밀렸다. 상수 하나에서 파생되는지 화면으로 확인한다.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: BusBodyAxis(view: _view(const ['5623'])),
          ),
        ),
      ));

      // **위치 기반 finder를 쓰지 않는다.** 예전에는 `find.byType(Container).at(1)`로
      // 점을 집었는데, 1분 보조 눈금이 들어오면서 그 인덱스가 밀렸다(레일·눈금·점이
      // 모두 Container다). 이름 있는 키는 그런 이동에 영향받지 않는다.
      final label = tester.getRect(find.text('5623'));
      final dot = tester.getRect(find.byKey(BusBodyAxis.dotKey('R0')));

      expect((label.center.dx - dot.center.dx).abs(), lessThan(1.0),
          reason: '라벨 중앙과 점 중앙이 어긋나면 어느 버스의 번호인지 알 수 없다');
    });

    testWidgets('긴 번호도 잘리지 않는다 — 축소해서 담는다', (tester) async {
      // 실측 `1006-1` 36.8pt는 34pt 박스를 넘는다. `FittedBox(scaleDown)`이 줄여
      // 담으므로 글자가 사라지지 않는다.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: BusBodyAxis(view: _view(const ['1006-1'])),
          ),
        ),
      ));

      expect(find.text('1006-1'), findsOneWidget);
      expect(tester.getRect(find.text('1006-1')).width,
          lessThanOrEqualTo(BusBodyAxis.labelWidth + 0.5),
          reason: '박스를 넘겨 그리면 옆 라벨과 겹치거나 잘린다');
    });
  });
}
