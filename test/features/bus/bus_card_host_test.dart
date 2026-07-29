import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/time_range.dart';
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

/// 수원시청(`GGB201000156`) **실측 GBIS 응답**을 그대로 쓴다.
///
/// [_stop]은 경기 정류장이므로 앱은 이 정류장을 GBIS로 조회한다 — 손으로 쓴 TAGO
/// 껍데기를 stub으로 두면 실제로 타지 않는 경로 위에서 호스트를 검증하게 된다
/// (교체 전에는 TAGO 껍데기였고, 분기가 들어오자 이 파일 7건이 한꺼번에 깨졌다).
///
/// 6노선이 오고 가장 빠른 것이 `92-1`(160초 → 3분)이다. 표시 상한(`busUnfilteredLimit`)이
/// 3이라 카드에는 `92-1`·`82-1`·`61` 세 줄만 보인다.
String _body() =>
    File('test/fixtures/gbis/arrivals_suwoncityhall_6routes.json')
        .readAsStringSync();

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

    testWidgets('꺼져 있고 슬롯이 남아 있어도 요청은 0이다 — 켜본 뒤 끈 사용자', (tester) async {
      // 위의 `스위치가 꺼져 있으면…`은 `BusSettings.defaults`를 넘겨 **슬롯도 없다** —
      // 그래서 `shouldPoll`에서 `settings.enabled &&`를 통째로 지워도 `stop == null`이
      // 대신 false를 만들어 통과한다. 프로덕션의 가장 흔한 OFF 상태는 슬롯이 남아
      // 있는 이 조합이고(켜서 정류장을 등록한 뒤 끈 사용자), 그때 그 절이 사라지면
      // 화면에 카드가 1픽셀도 없는데 30초마다 TAGO를 두드린다.
      final n = await _pumpHost(
        tester,
        now: inRange,
        settings: onWithStop.copyWith(enabled: false),
      );
      expect(find.byType(BusArrivalCard), findsNothing);
      expect(n, 0);
    });

    testWidgets('시간대 밖이면 접힌 채 그려지고 첫 조회조차 나가지 않는다', (tester) async {
      final n = await _pumpHost(tester, now: outOfRange, settings: onWithStop);
      expect(find.byType(BusArrivalCard), findsOneWidget);
      expect(find.textContaining('수원시청'), findsOneWidget);
      expect(find.text('92-1번'), findsNothing);
      expect(n, 0);
    });
  });

  group('시간대 안 — 펼쳐지고 조회한다', () {
    testWidgets('목록과 기준시각이 보인다', (tester) async {
      final n = await _pumpHost(tester, now: inRange, settings: onWithStop);
      expect(find.text('92-1번'), findsOneWidget);
      expect(find.text('3분'), findsOneWidget);
      expect(find.text('07:32 기준'), findsOneWidget);
      expect(n, 1);
    });

    testWidgets('이미 해석된 설정 위에서 마운트해도 첫 조회가 나간다 — warm mount', (tester) async {
      // 위의 `_pumpHost`는 항상 새 ProviderScope에서 AsyncLoading부터 출발하므로
      // 리스너가 반드시 한 번 발화한다 — 실사용의 두 경로(설정 탭에서 켠 직후,
      // 오늘↔캘린더 탭 왕복)는 **이미 AsyncData인 provider 위에서** 마운트되는데
      // 그 경로가 이 파일에 없었다. `ref.listen`은 변화만 받으므로 그때는 조회가
      // 영구히 나가지 않았다(카드가 `도착시간을 확인하고 있어요`로 얼어붙는다).
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
      final container = ProviderContainer(
        overrides: [busApiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      // = 설정 탭에서 스위치를 켠 시점. 이 뒤로 provider는 AsyncData다.
      await container.read(busSettingsProvider.future);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => inRange)),
        ),
      ));
      await tester.pumpAndSettle();

      expect(count, 1, reason: '이미 data인 설정 위에서 마운트해도 첫 조회는 나간다');
      expect(find.text('92-1번'), findsOneWidget);
      expect(find.text(BusStrings.emptyLoading), findsNothing);
    });
  });

  group('겹친 시간대 — 읽는 순간 복구되므로 카드가 죽지 않는다 (M5)', () {
    testWidgets('prefs에 겹친 시간대가 있어도 펼쳐지고 조회한다', (tester) async {
      // 복구가 없으면 `resolveBusDisplay`가 `!rangesValid`에서 override보다 먼저
      // `expanded: false`를 반환해 카드는 접힌 줄만 남고, 제목줄을 몇 번 눌러도
      // 펼쳐지지 않는다 — 도달 경로는 좁지만 증상은 기능 전체 사망이다.
      final n = await _pumpHost(
        tester,
        now: inRange,
        settings: onWithStop.copyWith(
          toHomeRange: const TimeRange.hm(8, 0, 18, 0), // 출근 07:00–08:30과 겹친다
        ),
      );
      expect(find.text('92-1번'), findsOneWidget);
      expect(find.text('07:32 기준'), findsOneWidget);
      expect(n, 1, reason: '시간대가 복구돼 조건 3(펼침)이 통과한다');
    });
  });

  group('제목줄 탭 — override 저장', () {
    testWidgets('시간대 안에서 접으면 본문이 사라지고 추가 요청이 없다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      // **시계는 가변이어야 한다.** 고정하면 첫 조회가 캐시를 채운 뒤 busCacheTtl이
      // 영원히 만료되지 않아, 이후 어떤 조회도 MockClient 앞에서 캐시로 끝난다 —
      // `_tick`의 expanded 가드를 지워도 count가 1이라 이 단정이 반증 불가가 된다.
      var now = inRange;
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
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => now))),
      ));
      await tester.pumpAndSettle();
      expect(count, 1);

      // 캐시를 넘긴다 — 이제 조회가 나가면 실제 요청이 되어 count에 잡힌다.
      now = now.add(const Duration(seconds: 31));

      await tester.tap(find.byKey(BusArrivalCard.headerKey));
      await tester.pumpAndSettle();

      expect(find.text('92-1번'), findsNothing);
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
      expect(find.text('92-1번'), findsOneWidget);
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

    testWidgets('캐시가 만료된 뒤 복귀하면 다시 조회한다', (tester) async {
      // 위의 `펼친 채 복귀…`는 캐시 흡수를 검사한다 — 그래서 복귀가 tick조차 하지
      // 않아도 통과한다. 촉발 자체를 고정하는 것은 이 테스트다: 시계를 밀어 캐시를
      // 만료시키면 복귀 tick이 네트워크까지 도달해야 한다.
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      var now = inRange;
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
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => now))),
      ));
      await tester.pumpAndSettle();
      expect(count, 1);

      now = now.add(const Duration(seconds: 31));
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(count, 2,
          reason: '복귀가 조회를 촉발한다 — 이 단정이 그 분기의 유일한 가드다');
    });
  });

  group('가드 — 포그라운드 (§6 조건 5)', () {
    // 이 조건은 여섯 중 **유일하게 단정이 0**이었다. 위의 라이프사이클 3개는 `paused`
    // 직후가 `pump()`(시간 전진 0)이고 `Timer.periodic`은 프레임을 예약하지 않아 30초에
    // 도달하지 못한다 — 그래서 타이머 취소 분기와 비행 중 재확인을 **둘 다 지워도**
    // 전부 초록이었다. 여기서 그 두 분기를 각각 발화시킨다.

    testWidgets('백그라운드로 내려가면 폴링 타이머가 멈춘다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      // **가변 clock이어야 한다** — 고정하면 캐시가 tick을 흡수해 타이머가 살아
      // 있어도 count가 그대로다(단정이 반증 불가가 된다).
      var now = inRange;
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
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => now))),
      ));
      await tester.pumpAndSettle();
      expect(count, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      now = now.add(const Duration(seconds: 31));
      await tester.pump(busPollInterval); // 취소되지 않았다면 여기서 발화한다
      await tester.pumpAndSettle();

      expect(count, 1,
          reason: '백그라운드에서는 폴링이 멈춘다 — 화면에 안 보이는 호출이라 '
              '화면 검증으로는 잡히지 않는다');
    });

    testWidgets('비행 중에 내려가면 응답이 돌아와도 타이머를 새로 걸지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      var now = inRange;
      final hold = Completer<void>();
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          await hold.future;
          return _json(_body());
        }),
        serviceKey: 'TESTKEY',
        clock: () => now,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => now))),
      ));
      await tester.pumpAndSettle();
      expect(count, 1, reason: '첫 조회가 비행 중이다');

      // 라이프사이클 콜백은 응답보다 **먼저** 지나간다 — 그 시점 `_timer`는 아직
      // null이라 취소할 것이 없고, 응답 처리 끝의 재확인만이 타이머를 막는다.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      hold.complete();
      await tester.pumpAndSettle();

      now = now.add(const Duration(seconds: 31));
      await tester.pump(busPollInterval);
      await tester.pumpAndSettle();

      expect(count, 1,
          reason: '비행 중 내려간 앱에 폴링 타이머가 걸리면 백그라운드에서 '
              '30초마다 호출이 나간다');
    });
  });

  group('다시 시도 — 비행 중 가드 (I11)', () {
    /// 첫 조회부터 실패시키고, `hold`가 완료될 때까지 두 번째 요청을 붙잡는다.
    /// 실패 경로는 캐시에 쓰지 않으므로 탭마다 캐시 미스 = 실제 요청이 된다.
    Future<int Function()> pumpDownCard(
      WidgetTester tester,
      Completer<void> hold,
    ) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          if (count >= 2) await hold.future;
          throw http.ClientException('네트워크 없음');
        }),
        serviceKey: 'TESTKEY',
        clock: () => inRange,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => inRange))),
      ));
      await tester.pumpAndSettle();

      expect(find.text(BusStrings.emptyDown), findsOneWidget);
      expect(find.text(BusStrings.emptyDownAction), findsOneWidget);
      expect(count, 1);
      return () => count;
    }

    testWidgets('연달아 두 번 눌러도 요청은 한 번만 늘어난다', (tester) async {
      final hold = Completer<void>();
      final count = await pumpDownCard(tester, hold);

      // **두 탭 사이에 pump를 넣지 않는다.** 리빌드가 오기 전이라 두 번째 탭도 같은
      // GestureDetector에 닿는다 — 라벨 교체가 아니라 `_retrying` 가드만이 막는다.
      // pump를 넣으면 버튼이 이미 진행 문구로 바뀌어 가드를 지워도 통과한다.
      await tester.tap(find.text(BusStrings.emptyDownAction));
      await tester.tap(find.text(BusStrings.emptyDownAction));

      expect(count(), 2,
          reason: '비행 중 두 번째 탭은 요청을 만들지 않는다 — 실패는 캐시되지 '
              '않으므로 가드가 없으면 탭 N번 = 동시 요청 N건이다');

      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('비행 중에는 다시 시도 자리에 진행 문구가 뜬다', (tester) async {
      final hold = Completer<void>();
      await pumpDownCard(tester, hold);

      await tester.tap(find.text(BusStrings.emptyDownAction));
      await tester.pump();

      expect(find.text(BusStrings.emptyDownRetrying), findsOneWidget,
          reason: '조회는 최대 10초 걸린다 — 화면이 안 바뀌면 사용자는 '
              '버튼이 안 먹은 줄 알고 다시 누른다');
      expect(find.text(BusStrings.emptyDownAction), findsNothing);

      hold.complete();
      await tester.pumpAndSettle();

      expect(find.text(BusStrings.emptyDownAction), findsOneWidget,
          reason: '끝나면 다시 누를 수 있어야 한다 — 영구 비활성이 아니다');
      expect(find.text(BusStrings.emptyDownRetrying), findsNothing);
    });

    testWidgets('재시도 가드는 폴링·복귀 촉발을 막지 않는다', (tester) async {
      // 전역 in-flight 가드는 이전 라운드에서 기각됐다(비행 중 도착한 tick을 버리면
      // 방향 전환이 최대 30초 빈 카드로 남는다). 가드가 `다시 시도`에만 걸려 있는지
      // 여기서 고정한다 — 재시도를 한 번 끝낸 뒤 폴링과 복귀가 그대로 도는지 본다.
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      var now = inRange;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          throw http.ClientException('네트워크 없음');
        }),
        serviceKey: 'TESTKEY',
        clock: () => now,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => now))),
      ));
      await tester.pumpAndSettle();
      expect(count, 1);

      await tester.tap(find.text(BusStrings.emptyDownAction));
      await tester.pumpAndSettle();
      expect(count, 2, reason: '재시도 1회는 나간다');

      now = now.add(const Duration(seconds: 31));
      await tester.pump(busPollInterval);
      await tester.pumpAndSettle();
      expect(count, 3, reason: '재시도가 끝난 뒤에도 폴링 타이머는 살아 있다');

      now = now.add(const Duration(seconds: 31));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(count, 4, reason: '복귀 촉발도 그대로다 — 가드는 버튼에만 걸린다');
    });
  });

  group('도달하지 않는 콜백은 넘기지 않는다 (M25)', () {
    testWidgets('조회 전 로딩 카드에는 다시 시도가 없다', (tester) async {
      // 이 분기는 `state: ok` + 빈 목록이라 BusEmptyState의 ok 튜플이 action을
      // null로 준다 — 넘긴 `onRetry`가 도달할 자리가 없다.
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      final hold = Completer<void>();
      final client = BusApiClient(
        client: MockClient((_) async {
          await hold.future;
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

      expect(find.text(BusStrings.emptyLoading), findsOneWidget);
      expect(find.text(BusStrings.emptyDownAction), findsNothing);
      expect(find.text(BusStrings.emptyNoStopAction), findsNothing);

      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('조회 실패 카드에는 정류장 등록이 없다', (tester) async {
      // `fetch.state`가 낼 수 있는 값에 noStop이 없으므로 `onRegister`도 도달하지
      // 않는다. 슬롯이 비었을 때만 등록 유도가 뜬다(위의 `슬롯이 비면…` 테스트).
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      final client = BusApiClient(
        client: MockClient((_) async => throw http.ClientException('네트워크 없음')),
        serviceKey: 'TESTKEY',
        clock: () => inRange,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => inRange))),
      ));
      await tester.pumpAndSettle();

      expect(find.text(BusStrings.emptyDown), findsOneWidget);
      expect(find.text(BusStrings.emptyNoStopAction), findsNothing);
    });
  });

  group('폴링 — busPollInterval', () {
    testWidgets('30초마다 다시 조회한다', (tester) async {
      // 첫 조회 1건 → 시계를 31초 밀고 타이머를 발화시키면 캐시가 만료돼 2건이 된다.
      // 시계를 밀지 않으면 tick이 캐시 히트로 끝나 이 테스트는 아무것도 증명하지 못한다.
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      var now = inRange;
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
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => now))),
      ));
      await tester.pumpAndSettle();
      expect(count, 1);

      now = now.add(const Duration(seconds: 31));
      await tester.pump(busPollInterval);
      await tester.pumpAndSettle();

      expect(count, 2, reason: '폴링 타이머가 실제로 걸려 있다');
    });

    testWidgets('폴링이 도는 동안 목록이 사라지지 않는다', (tester) async {
      // 표시 드롭 임계값을 `busCacheTtl`(30초)로 두면 `fetchedAt`이 요청 **시작**
      // 시각이고 폴링은 응답 **뒤** 30초라 `d+30 > 30`이 항상 참이 되어, 정상
      // 폴링마다 목록이 사라지고 `도착시간을 확인하고 있어요`가 떴다. 두 번째
      // 응답을 붙잡아 그 중간 프레임을 관찰한다 — 붙잡지 않으면 pumpAndSettle이
      // 목록을 되살려 드롭이 보이지 않는다.
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      var now = inRange;
      final hold = Completer<void>();
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          if (count == 2) await hold.future;
          return _json(_body());
        }),
        serviceKey: 'TESTKEY',
        clock: () => now,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => now))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('92-1번'), findsOneWidget);

      now = now.add(const Duration(seconds: 31));
      await tester.pump(busPollInterval); // 타이머 발화 → 두 번째 요청이 비행 중
      await tester.pump(); // 드롭이 있었다면 이 프레임에서 보인다

      expect(count, 2);
      expect(find.text('92-1번'), findsOneWidget,
          reason: '갱신 중에도 직전 목록을 유지한다 — 3분을 넘긴 값만 내린다');
      expect(find.text(BusStrings.emptyLoading), findsNothing);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.text('92-1번'), findsOneWidget);
    });

    testWidgets('시간대가 끝나면 다음 tick이 카드를 접고 옛 목록을 버린다', (tester) async {
      // 타이머만 끊고 setState 없이 return하면 카드를 리빌드시키는 신호가 없어
      // 펼친 카드가 마지막 프레임(옛 도착 분)에 얼어붙는다 — 폴링이 멈춘 카드가
      // 살아 있는 것처럼 보이는, 이 카드에서 가장 위험한 실패다.
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      var now = DateTime(2026, 7, 28, 8, 29); // 출근 시간대(07:00–08:30) 끝자락
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
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => now))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('92-1번'), findsOneWidget);
      expect(count, 1);

      now = DateTime(2026, 7, 28, 8, 31); // 시간대 종료
      await tester.pump(busPollInterval);
      await tester.pumpAndSettle();

      expect(find.text('92-1번'), findsNothing,
          reason: '시간대가 끝나면 카드가 접히고 옛 도착 분이 남지 않는다');
      expect(find.textContaining('기준'), findsNothing);
      expect(find.textContaining('수원시청'), findsOneWidget,
          reason: '접힌 줄은 남는다 — 카드가 사라지는 것이 아니다');
      expect(count, 1, reason: '접힌 뒤에는 요청이 늘지 않는다');
    });
  });

  group('제목줄 새로고침', () {
    testWidgets('펼친 카드에는 새로고침이 있다', (tester) async {
      await _pumpRefreshHost(tester, start: inRange, settings: onWithStop);

      expect(find.byKey(BusArrivalCard.refreshKey), findsOneWidget);
    });

    testWidgets('접힌 카드에는 없다 — 눌러도 결과를 볼 수 없다', (tester) async {
      // 시간대 밖이면 접힌 채로 뜬다. 폴링도 멈춰 있다.
      await _pumpRefreshHost(tester, start: outOfRange, settings: onWithStop);

      expect(find.byKey(BusArrivalCard.refreshKey), findsNothing);
    });

    testWidgets('캐시가 신선하면 눌러도 요청이 나가지 않는다 — 캐시가 스로틀이다', (tester) async {
      final h = await _pumpRefreshHost(
        tester,
        start: inRange,
        settings: onWithStop,
      );
      expect(h.count(), 1);

      await tester.tap(find.byKey(BusArrivalCard.refreshKey));
      await tester.pumpAndSettle();

      expect(h.count(), 1,
          reason: '30초 캐시가 답한다 — 별도 스로틀 코드가 없는 이유다');
    });

    testWidgets('30초가 지난 뒤 누르면 다시 조회한다', (tester) async {
      final h = await _pumpRefreshHost(
        tester,
        start: inRange,
        settings: onWithStop,
      );
      expect(h.count(), 1);

      h.advance(const Duration(seconds: 31));
      await tester.tap(find.byKey(BusArrivalCard.refreshKey));
      await tester.pumpAndSettle();

      expect(h.count(), 2);
    });

    testWidgets('새로고침을 눌러도 카드가 접히지 않는다', (tester) async {
      // 제목줄 **전체**가 접기 표적이고 새로고침은 그 안에 있다. 안쪽
      // `GestureDetector`가 히트 테스트를 먼저 먹어야 한다 — 아니면 새로고침을
      // 누를 때마다 카드가 접혀 결과를 볼 수 없다.
      await _pumpRefreshHost(tester, start: inRange, settings: onWithStop);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      await tester.tap(find.byKey(BusArrivalCard.refreshKey));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsOneWidget,
          reason: '펼친 상태가 유지돼야 한다');
      expect(find.byKey(BusArrivalCard.refreshKey), findsOneWidget);
    });
  });
}

/// 새로고침 테스트용 — 시계와 요청 수를 테스트가 직접 만진다.
///
/// `_pumpHost`는 요청 수를 **그 시점 값으로** 돌려주고 시계가 고정이라, 탭 이후를
/// 볼 수 없고 30초 캐시도 절대 만료되지 않는다. 새로고침은 그 둘이 다 필요하다.
Future<({int Function() count, void Function(Duration) advance})>
    _pumpRefreshHost(
  WidgetTester tester, {
  required DateTime start,
  required BusSettings settings,
}) async {
  SharedPreferences.setMockInitialValues({
    'bus_settings_v1': jsonEncode(settings.toJson()),
  });

  var now = start;
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
  return (count: () => count, advance: (Duration d) => now = now.add(d));
}
