// ignore_for_file: avoid_print
//
// App Store 심사용 스크린샷 자동 촬영.
//
// 실행:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_test.dart \
//     -d <UDID>
//
// 결과: docs/screenshots/{1_today,2_calendar,3_schedule,4_import,5_settings,6_bus}.png
//
// 드라이버가 루트에 쓴다 → App Store 제출용은 규격별 폴더로 옮긴다.
//   6.9" (1320x2868, iPhone 17 Pro Max) → docs/screenshots/appstore/6.9/
//   6.5" (1284x2778, iPhone 12 Pro Max) → docs/screenshots/appstore/6.5/
// 두 규격을 모두 두는 이유: 기존 승인본이 6.5"라 like-for-like 교체가 되고,
// ASC가 6.9"를 요구해도 바로 대응된다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/dev/screenshot_seed.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/domain/time_range.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/settings/presentation/providers/stamp_settings_provider.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';

/// 버스 카드 촬영용 결정적 클라이언트.
///
/// 실제 조회를 쓰면 스크린샷이 **촬영 시각에 좌우된다** — 심야에 돌리면
/// `오늘 운행이 끝났어요`가 찍히고, 낮에도 배차에 따라 노선 수가 달라진다.
/// TAGO 키가 없는 빌드에서는 `keyError`가 찍힌다.
///
/// `fetchArrivals` 하나만 덮는다 — 카드(`bus_card_host.dart`)가 부르는 것이
/// 그것뿐이다. 정류장 검색(`fetchViaRoutes` 등)은 이 화면에 없다.
class _ScreenshotBusApi extends BusApiClient {
  _ScreenshotBusApi() : super(serviceKey: 'screenshot');

  @override
  Future<BusFetch> fetchArrivals({
    required int cityCode,
    required String nodeId,
  }) async {
    // **기준 시각을 아침으로 고정한다.** `fetchedAt`이 곧 카드의 `07:42 기준`
    // 문구인데, 실제 시각을 쓰면 심야에 촬영하면 `출근` 카드에 `00:22 기준`이
    // 찍혀 그 자체로 모순된 화면이 스토어에 올라간다.
    //
    // 도착시간은 흔들리지 않는다 — `buildBusCardView`의 경과 보정은
    // `elapsed <= 0`이면 원본을 그대로 돌려준다(`bus_card_view.dart:99`).
    final now = DateTime.now();
    return BusFetch(
      state: BusCardState.ok,
      fetchedAt: DateTime(now.year, now.month, now.day, 7, 42),
      arrivals: const [
        // 1차 95초(1분) + 2차 620초 — 같은 노선의 뒤차까지 보여 축의 속 빈 점이 그려진다.
        BusArrival(
          routeId: 'SCR-150',
          routeNo: '150',
          arrSec: 95,
          arrSec2: 620,
          vehicleId: 'SCR-150-A',
          vehicleId2: 'SCR-150-B',
          lowFloor: true,
        ),
        BusArrival(
          routeId: 'SCR-405',
          routeNo: '405',
          arrSec: 320,
          vehicleId: 'SCR-405-A',
        ),
        BusArrival(
          routeId: 'SCR-750',
          routeNo: '750A',
          arrSec: 760,
          vehicleId: 'SCR-750-A',
        ),
      ],
    );
  }
}

/// 촬영용 정류장 — **서울 공공 랜드마크만 쓴다.**
///
/// 개발자가 실제로 등록해 쓰는 정류장을 넣으면 스토어 스크린샷으로 생활 반경이
/// 드러난다(CLAUDE.md '실측 정류장 이름은 익명 라벨로 적는다').
const _screenshotStop = BusStop(
  nodeId: 'GGB02004',
  nodeNm: '서울역버스환승센터',
  nodeNo: 2004,
  cityCode: 0,
  regionName: '서울',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App Store용 6화면 스크린샷 촬영', (tester) async {
    // DB 초기화 후 seed 주입
    await DatabaseHelper.instance.resetAllData();
    final container = ProviderContainer(
      overrides: [
        busApiClientProvider.overrideWithValue(_ScreenshotBusApi()),
      ],
    );
    await seedScreenshotData(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PlanRoutineApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 1. 오늘 탭 (기본 진입) — 스토어에서는 도장이 선명해야 하므로 '흐리게'를 끈다.
    await container
        .read(stampSettingsProvider.notifier)
        .setDimPreviousStamps(false);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('1_today');

    // 2. 캘린더 탭
    await tester.tap(find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(Icons.calendar_month_outlined),
    ));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('2_calendar');

    // 3. 입력 탭
    final scheduleTab = find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(Icons.note_add_outlined),
    );
    await tester.tap(scheduleTab.first);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    // convert 직후 한 프레임 더 돌린다 — IntegrationTestWidgetsFlutterBinding은
    // LiveTestWidgetsFlutterBinding이라 **마지막 테스트 포인터 위치에 라임색 조준선**을
    // 그린다. 이 pump가 없으면 그 프레임이 그대로 캡처돼 방금 누른 탭 아이콘 위에
    // 십자선이 박힌 채 App Store에 올라간다(실측: 6.9_3_input).
    await tester.pumpAndSettle();
    await binding.takeScreenshot('3_input');

    // 5. 설정 탭
    final settingsTab = find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(Icons.settings_outlined),
    );
    await tester.tap(settingsTab.first);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('5_settings');

    // 4. 입력 탭 히어로의 CSV 링크 → Import 풀스크린 + 에듀파인 가이드 펼침
    // (설정 탭의 가져오기 섹션은 히어로와 중복이라 없앴다)
    await tester.tap(scheduleTab.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ImportStrings.heroCsvLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ImportStrings.edufineGuideTitle));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('4_import');

    // 6. 오늘 탭 + 버스 도착 카드 (1.3.0)
    //
    // **버스는 맨 마지막에 켠다.** 카드가 살아 있는 동안 `BusCardHost`가 1초짜리
    // 이동 틱(`Timer.periodic`)으로 setState를 반복하므로, 그 뒤로는
    // `pumpAndSettle`이 "예약된 프레임 없음"에 도달하지 못해 타임아웃까지 매달린다.
    // 앞의 5장을 먼저 찍어두면 그 함정과 무관해진다.
    await tester.tap(find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.byIcon(Icons.check_circle_outline),
    ));
    await tester.pumpAndSettle();

    await container.read(busSettingsProvider.future);
    final bus = container.read(busSettingsProvider.notifier);
    // **퇴근 시간대를 먼저 옮긴다** — 출근 시간대를 하루 전체로 넓히려면 기본
    // 퇴근 시간대(16:00–18:00)와 겹치는데, `setRange`는 겹치는 값을 저장하지 않고
    // false를 돌려준다. 순서를 뒤집으면 조용히 거부돼 카드가 접힌 채 찍힌다.
    await bus.setRange(CommuteDirection.toHome, const TimeRange.hm(23, 10, 23, 50));
    // 촬영 시각과 무관하게 펼쳐지도록 출근 시간대가 하루를 덮게 한다.
    await bus.setRange(CommuteDirection.toWork, const TimeRange.hm(0, 0, 23, 0));
    await bus.setStop(CommuteDirection.toWork, _screenshotStop);
    // 시간 축 — 배차 간격이 공간으로 보여 스토어에서 기능이 한눈에 읽힌다.
    await bus.setStyle(BusCardStyle.axis);
    await bus.setEnabled(true);

    // `pumpAndSettle`을 쓰지 않는다(위 주석). 조회 1회 + 카드 렌더가 끝날 만큼만 돌린다.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 250));
    await binding.takeScreenshot('6_bus');

    // 타이머를 끊어 둔다 — 켜진 채로 테스트가 끝나면 이동 틱이 teardown까지 남는다.
    await bus.setEnabled(false);
    await tester.pump(const Duration(milliseconds: 250));
  });
}
