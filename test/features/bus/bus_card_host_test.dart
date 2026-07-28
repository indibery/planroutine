import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_arrival_card.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_card_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '수원시청',
  nodeNo: 2251,
  cityCode: 31010,
);

String _body() => jsonEncode({
      'response': {
        'header': {'resultCode': '00', 'resultMsg': 'NORMAL SERVICE.'},
        'body': {
          'items': {
            'item': [
              {
                'arrprevstationcnt': 3,
                'arrtime': 120,
                'nodeid': 'GGB201000156',
                'nodenm': '수원시청',
                'routeid': 'R1',
                'routeno': 720,
                'vehicletp': '일반버스',
              }
            ]
          },
          'numOfRows': 30,
          'pageNo': 1,
        },
      },
    });

/// TAGO는 UTF-8 JSON을 준다. **content-type을 빼면 안 된다** — package:http가
/// `_encodingForHeaders`로 인코딩을 유도하고 헤더가 없으면 latin1로 떨어져,
/// 픽스처의 한글(`수원시청`)에서 `MockClient` 핸들러 안에서 터진다(구현이 아니라
/// 픽스처의 함정 — 실제로 한 번 발생했다). 구현은 utf8.decode(bodyBytes)로 맞다.
http.Response _json(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// 지정한 시각으로 고정한 채 카드를 띄우고, 나간 요청 수를 돌려준다.
Future<int> _pumpHost(
  WidgetTester tester, {
  required DateTime now,
  required BusSettings settings,
}) async {
  SharedPreferences.setMockInitialValues({
    'bus_settings_v1': jsonEncode(settings.toJson()),
  });

  var count = 0;
  final client = BusApiClient(
    client: MockClient((_) async {
      count++;
      return _json(_body());
    }),
    serviceKey: 'TESTKEY',
    clock: () => now,
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [busApiClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      home: Scaffold(body: BusCardHost(clock: () => now)),
    ),
  ));
  await tester.pumpAndSettle();
  return count;
}

void main() {
  // 기본 시간대: 출근 07:00–08:30 / 퇴근 16:00–18:00.
  final inRange = DateTime(2026, 7, 28, 7, 32);
  final outOfRange = DateTime(2026, 7, 28, 10, 20);

  final onWithStop = BusSettings.defaults.copyWith(
    enabled: true,
    departure: _stop,
    arrival: _stop,
  );

  group('가드 — 조건이 하나라도 거짓이면 요청 0회', () {
    testWidgets('스위치가 꺼져 있으면 카드가 없고 요청도 0이다', (tester) async {
      final n = await _pumpHost(
        tester,
        now: inRange,
        settings: BusSettings.defaults,
      );
      expect(find.byType(BusArrivalCard), findsNothing);
      expect(n, 0);
    });

    testWidgets('슬롯이 비면 등록 유도가 뜨고 요청은 0이다 — 무한 로딩 금지', (tester) async {
      final n = await _pumpHost(
        tester,
        now: inRange,
        settings: BusSettings.defaults.copyWith(enabled: true),
      );
      expect(find.text('정류장을 등록하면 도착시간이 보여요'), findsOneWidget);
      expect(n, 0);
    });

    testWidgets('시간대 밖이면 접힌 채 그려지고 첫 조회조차 나가지 않는다', (tester) async {
      final n = await _pumpHost(tester, now: outOfRange, settings: onWithStop);
      expect(find.byType(BusArrivalCard), findsOneWidget);
      expect(find.textContaining('수원시청'), findsOneWidget);
      expect(find.text('720번'), findsNothing);
      expect(n, 0);
    });
  });

  group('시간대 안 — 펼쳐지고 조회한다', () {
    testWidgets('목록과 기준시각이 보인다', (tester) async {
      final n = await _pumpHost(tester, now: inRange, settings: onWithStop);
      expect(find.text('720번'), findsOneWidget);
      expect(find.text('2분'), findsOneWidget);
      expect(find.text('07:32 기준'), findsOneWidget);
      expect(n, 1);
    });
  });

  group('제목줄 탭 — override 저장', () {
    testWidgets('시간대 안에서 접으면 본문이 사라지고 추가 요청이 없다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return _json(_body());
        }),
        serviceKey: 'TESTKEY',
        clock: () => inRange,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => inRange))),
      ));
      await tester.pumpAndSettle();
      expect(count, 1);

      await tester.tap(find.byKey(BusArrivalCard.headerKey));
      await tester.pumpAndSettle();

      expect(find.text('720번'), findsNothing);
      expect(find.text('07:32 기준'), findsNothing);
      expect(count, 1, reason: '접힘 상태에서는 요청이 늘지 않는다');
    });

    testWidgets('시간대 밖에서 펼치면 그때 조회한다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return _json(_body());
        }),
        serviceKey: 'TESTKEY',
        clock: () => outOfRange,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => outOfRange)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(count, 0);

      await tester.tap(find.byKey(BusArrivalCard.headerKey));
      await tester.pumpAndSettle();

      expect(count, 1);
      expect(find.text('720번'), findsOneWidget);
    });
  });

  group('키가 없으면 기능이 명시적으로 꺼진다', () {
    testWidgets('키 문구가 뜨고 요청은 0이다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return _json(_body());
        }),
        serviceKey: '',
        clock: () => inRange,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => inRange))),
      ));
      await tester.pumpAndSettle();

      expect(find.text('버스 정보를 불러올 수 없어요'), findsOneWidget);
      expect(count, 0);
    });
  });

  group('가드 — 백그라운드 복귀 (§6의 새는 구멍)', () {
    testWidgets('접힌 채 복귀하면 요청이 0회다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return _json(_body());
        }),
        serviceKey: 'TESTKEY',
        clock: () => outOfRange, // 시간대 밖 → 접힘
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => outOfRange)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(count, 0);

      // 백그라운드 → 복귀
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(count, 0,
          reason: '접힘에서는 복귀해도 조회하지 않는다 — 화면이 안 바뀌므로 '
              '화면 검증으로는 잡히지 않는 누수다');
    });

    testWidgets('펼친 채 복귀하면 캐시가 살아 있어 1회를 넘지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return _json(_body());
        }),
        serviceKey: 'TESTKEY',
        clock: () => inRange, // 시간대 안 → 펼침
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => inRange)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(count, 1);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(count, 1, reason: '30초 캐시가 복귀 조회를 흡수한다');
    });
  });
}
