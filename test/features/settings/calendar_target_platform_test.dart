import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/providers/calendar_target_provider.dart';
import 'package:planroutine/features/settings/presentation/widgets/calendar_integration_section.dart';

/// 안드로이드에서는 Google 캘린더 연동을 제공하지 않는다.
///
/// 근거(실측 2026-08-03): 안드로이드의 "기기 캘린더"는 `CalendarContract`이고
/// 그 안이 이미 동기화된 구글 캘린더다 — 저장한 이벤트가 `account_type=com.google`
/// 캘린더에 들어갔다. REST API 경로는 중복인데 GCP 클라이언트 등록이 없으면
/// `ApiException: 10`(DEVELOPER_ERROR)로만 보인다. iOS는 EventKit이 iCloud/로컬이라
/// 이 경로가 구글로 가는 유일한 길이므로 그대로 둔다.
///
/// 플랫폼 판정은 `googleTargetSupportedProvider` 한 곳뿐이다. 선택지와 스와이프
/// 분기가 같은 값을 봐야 "고를 수 없는데 스와이프는 가는" 막다른 길이 안 생긴다.
void main() {
  Widget host({required bool supported}) {
    return ProviderScope(
      overrides: [
        googleTargetSupportedProvider.overrideWithValue(supported),
      ],
      child: const MaterialApp(
        home: Scaffold(body: CalendarIntegrationSection()),
      ),
    );
  }

  group('저장값 강등', () {
    test('지원하지 않으면 저장된 google은 none으로 낮춘다', () async {
      SharedPreferences.setMockInitialValues({'calendar_target': 'google'});
      final container = ProviderContainer(overrides: [
        googleTargetSupportedProvider.overrideWithValue(false),
      ]);
      addTearDown(container.dispose);

      final target = await container.read(calendarTargetProvider.future);
      // 스와이프 분기(calendar_screen)도 이 값을 보므로, 여기서 낮추면
      // 설정에서 고를 수 없는데 스와이프만 Google로 가는 상태가 사라진다.
      expect(target, CalendarTarget.none);
    });

    test('지원하면 저장된 google을 그대로 쓴다', () async {
      SharedPreferences.setMockInitialValues({'calendar_target': 'google'});
      final container = ProviderContainer(overrides: [
        googleTargetSupportedProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);

      expect(await container.read(calendarTargetProvider.future),
          CalendarTarget.google);
    });

    test('device는 플랫폼과 무관하게 살아 있다', () async {
      SharedPreferences.setMockInitialValues({'calendar_target': 'device'});
      final container = ProviderContainer(overrides: [
        googleTargetSupportedProvider.overrideWithValue(false),
      ]);
      addTearDown(container.dispose);

      expect(await container.read(calendarTargetProvider.future),
          CalendarTarget.device);
    });
  });

  group('선택 시트', () {
    testWidgets('지원하지 않으면 Google 선택지가 없다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(host(supported: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text(CalendarIntegrationStrings.targetLabel));
      await tester.pumpAndSettle();

      expect(find.text(CalendarIntegrationStrings.targetNone), findsWidgets);
      expect(find.text(CalendarIntegrationStrings.targetDevice), findsOneWidget);
      expect(find.text(CalendarIntegrationStrings.targetGoogle), findsNothing);
    });

    testWidgets('지원하면 Google 선택지가 있다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(host(supported: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text(CalendarIntegrationStrings.targetLabel));
      await tester.pumpAndSettle();

      expect(find.text(CalendarIntegrationStrings.targetGoogle), findsOneWidget);
      expect(find.text(CalendarIntegrationStrings.targetDevice), findsOneWidget);
    });
  });
}
