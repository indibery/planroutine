import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_card_host.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: 'B정류장',
  nodeNo: 2251,
  cityCode: 31010,
);

String _body() => File(
  'test/fixtures/gbis/arrivals_suwoncityhall_6routes.json',
).readAsStringSync();

http.Response _json(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 가장 빠른 버스의 **차량** ID. 픽스처의 `92-1`(160초, `vehId1=200010883`).
///
/// **노선 ID가 아니다** — 축의 점은 노선이 아니라 "지금 오고 있는 이 버스"로
/// 묶인다. 노선으로 묶던 시절에는 앞차가 지나갈 때 점이 시간을 거슬러 오른쪽으로
/// 미끄러졌다([BusBodyAxis.dotKeyFor] 참고).
const _fastestVehicleId = '200010883';

void main() {
  // **이 파일이 덮는 것은 배선이다.** `dotPosition`이 초를 쓰는 것과 축 위젯이
  // 움직이는 것은 `bus_axis_movement_test`가 이미 고정했다. 여기서 보는 것은
  // "호스트의 1초 틱이 실제로 리빌드를 일으키고, 그 리빌드가 조회를 부르지
  // 않는다"는 두 가지다 — 둘 다 순수 함수 테스트로는 닿지 않는다.
  testWidgets('1초가 지나면 조회 없이 점이 왼쪽으로 간다', (tester) async {
    final settings = BusSettings.defaults.copyWith(
      enabled: true,
      departure: _stop,
      style: BusCardStyle.axis,
    );
    SharedPreferences.setMockInitialValues({
      'bus_settings_v1': jsonEncode(settings.toJson()),
    });

    // 출근 시간대 안. **가변 clock이어야 한다** — 고정하면 경과 보정이 늘 0이라
    // 점이 제자리에 있고, 타이머를 지워도 이 테스트가 초록으로 남는다.
    var now = DateTime(2026, 7, 28, 7, 32);
    var calls = 0;
    final client = BusApiClient(
      client: MockClient((_) async {
        calls++;
        return _json(_body());
      }),
      serviceKey: 'TESTKEY',
      clock: () => now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => now)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1, reason: '첫 조회는 나가야 한다');
    final dot = find.byKey(BusBodyAxis.dotKeyFor(_fastestVehicleId));
    expect(dot, findsOneWidget, reason: '시간 축 모양이어야 점이 그려진다');
    final before = tester.getRect(dot).center.dx;

    // 1초만 흘린다. 폴링(30초)에는 한참 못 미치므로 조회는 늘지 않아야 한다.
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // AnimatedPositioned가 1초에 걸쳐 옮기므로 그 애니메이션을 끝까지 돌린다.
    await tester.pumpAndSettle();

    final after = tester.getRect(dot).center.dx;

    expect(
      after,
      lessThan(before),
      reason: '1초 틱이 리빌드를 일으키지 않으면 점이 30초마다 순간이동한다',
    );
    expect(calls, 1, reason: '이동 틱은 네트워크를 부르지 않는다');
  });

  testWidgets('조회 간격이 규칙대로 걸린다 — 이르면 안 나가고 때가 되면 나간다', (tester) async {
    // 픽스처 최속 노선이 160초라 규칙은 min(300, 160+30) = 190초를 준다.
    // **양쪽을 다 본다** — 늦게만 검사하면 30초 고정으로 되돌려도 통과한다
    // (190초를 밀면 어차피 발화하므로).
    final settings = BusSettings.defaults.copyWith(
      enabled: true,
      departure: _stop,
      style: BusCardStyle.axis,
    );
    SharedPreferences.setMockInitialValues({
      'bus_settings_v1': jsonEncode(settings.toJson()),
    });

    var now = DateTime(2026, 7, 28, 7, 32);
    var calls = 0;
    final client = BusApiClient(
      client: MockClient((_) async {
        calls++;
        return _json(_body());
      }),
      serviceKey: 'TESTKEY',
      clock: () => now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => now)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);

    // 189초 — 아직 때가 아니다. 30초 고정이었다면 여기서 6번 더 나갔다.
    now = now.add(const Duration(seconds: 189));
    await tester.pump(const Duration(seconds: 189));
    expect(calls, 1, reason: '간격 전에는 조회가 나가지 않는다');

    // 190초 — 규칙이 정한 시각.
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(calls, 2, reason: '간격이 지나면 정확히 한 번 나간다');
  });

  testWidgets('백그라운드로 내려가면 이동 틱도 멈춘다', (tester) async {
    final settings = BusSettings.defaults.copyWith(
      enabled: true,
      departure: _stop,
      style: BusCardStyle.axis,
    );
    SharedPreferences.setMockInitialValues({
      'bus_settings_v1': jsonEncode(settings.toJson()),
    });

    var now = DateTime(2026, 7, 28, 7, 32);
    final client = BusApiClient(
      client: MockClient((_) async => _json(_body())),
      serviceKey: 'TESTKEY',
      clock: () => now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => now)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    final dot = find.byKey(BusBodyAxis.dotKeyFor(_fastestVehicleId));
    final before = tester.getRect(dot).center.dx;

    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));

    expect(
      tester.getRect(dot).center.dx,
      before,
      reason: '내려간 뒤에도 초당 리빌드가 남으면 배터리를 조용히 쓴다',
    );
  });
}
