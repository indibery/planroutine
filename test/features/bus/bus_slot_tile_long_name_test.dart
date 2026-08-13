import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart';

/// 실측 정류장 이름. 서울·경기에는 이만큼 긴 이름이 실재한다
/// (실기기 신고 2026-07-30 — 이 이름이 화면을 깨뜨렸다).
const _longName = '석수체육공원.자동차학원.원태우지사의거지';

BusStop _stop(String name) =>
    BusStop(nodeId: 'GGB1', nodeNm: name, nodeNo: 1, cityCode: 0);

Future<void> _pump(
  WidgetTester tester,
  String arrivalName,
  double width,
) async {
  final settings = BusSettings.defaults.copyWith(
    enabled: true,
    departure: _stop('장미아파트'),
    arrival: _stop(arrivalName),
  );
  SharedPreferences.setMockInitialValues({
    'bus_settings_v1': jsonEncode(settings.toJson()),
  });

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: const SingleChildScrollView(child: BusSettingsTiles()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('정류장 이름이 길어도 행이 무너지지 않는다', () {
    // **행 제목이 세로로 쪼개진 것이 신고 내용이다.** `trailing`에 폭 제한이 없어
    // 긴 이름이 가로를 다 먹고 `title`·`subtitle`에 두 글자 폭만 남았다.
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('$width pt — 제목이 한 줄로 선다', (tester) async {
        await _pump(tester, _longName, width);

        final title = tester.getRect(find.text(BusStrings.slotArrival));
        expect(
          title.height,
          lessThan(30),
          reason: '제목이 여러 줄로 쪼개졌다 — trailing이 폭을 다 먹었다',
        );
      });

      testWidgets('$width pt — 부제가 두 줄을 넘지 않는다', (tester) async {
        // 제목과 달리 부제는 **두 줄까지 허용한다.** `학교 근처에서 타는 정류장`은
        // 320pt에서 남는 폭(약 145pt)에 한 줄로 안 들어간다 — trailing을 더 조이면
        // 이번엔 정류장 이름이 두 글자만 남는다.
        //
        // 원래 버그는 부제가 **일곱 줄**이었다(제목은 여섯 줄). 두 줄은 정상 줄바꿈이다.
        await _pump(tester, _longName, width);

        final hint = tester.getRect(find.text(BusStrings.slotArrivalHint));
        expect(
          hint.height,
          lessThan(45),
          reason: '세 줄 이상이면 trailing이 다시 폭을 먹고 있다',
        );
      });
    }

    testWidgets('짧은 이름은 잘리지 않는다', (tester) async {
      await _pump(tester, '중앙공원', 390);
      expect(find.text('중앙공원'), findsOneWidget);
    });

    testWidgets('긴 이름도 위젯 자체는 남는다 — 생략만 된다', (tester) async {
      await _pump(tester, _longName, 320);
      expect(find.text(_longName), findsOneWidget);
    });
  });
}
