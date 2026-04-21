import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';

/// 설정 탭 내부에서 target이 화면에 보일 때까지 스크롤한 뒤 다음 액션을 허용한다.
/// 설정 ListView가 알림/Google/휴지통/데이터관리/앱정보로 길어져 fold 아래 항목이
/// 기본 viewport에 없기 때문.
///
/// 새 UI는 `extendBody: true` + FloatingTabBar 조합이라 ListView가 탭바 아래까지
/// 이어진다. scrollUntilVisible의 기본 drag 시작점(Scrollable 중앙)이 탭바에 덮여
/// hit-test가 실패하므로, 상단 근처에서 수동 drag 로 스크롤한다.
Future<void> _scrollToInSettings(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 20; i++) {
    if (target.evaluate().isNotEmpty) {
      break;
    }
    await tester.dragFrom(const Offset(200, 200), const Offset(0, -240));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

/// FloatingTabBar 안의 특정 아이콘(선택/비선택 모두)을 탭한다.
Future<void> _tapTab(
  WidgetTester tester, {
  required IconData icon,
  required IconData activeIcon,
}) async {
  final candidates = find.descendant(
    of: find.byType(FloatingTabBar),
    matching: find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == icon || w.icon == activeIcon),
    ),
  );
  await tester.tap(candidates.first);
  await tester.pumpAndSettle();
}

Future<void> _tapCalendarTab(WidgetTester tester) => _tapTab(
      tester,
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
    );

Future<void> _tapScheduleTab(WidgetTester tester) => _tapTab(
      tester,
      icon: Icons.checklist_rtl_outlined,
      activeIcon: Icons.checklist_rtl,
    );

Future<void> _tapSettingsTab(WidgetTester tester) => _tapTab(
      tester,
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    );

/// 캘린더 화면의 gold FAB(Container + InkWell) 탭. Icons.add 한 개만 존재한다고 가정.
Future<void> _tapAddFab(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
}

/// 각 테스트를 깨끗한 상태(캘린더 탭 + 빈 DB)에서 시작시킨다.
/// appRouter / DatabaseHelper가 싱글톤이라 테스트 간 상태가 누적된다.
Future<void> _startFresh(WidgetTester tester) async {
  await DatabaseHelper.instance.resetAllData();
  // onboardingDone=true 기본값으로 바로 /calendar 진입
  await tester.pumpWidget(const ProviderScope(child: PlanRoutineApp()));
  await tester.pumpAndSettle();
  // 이전 테스트 영향으로 다른 탭에 있을 수 있으니 캘린더로 복귀
  if (find.byType(FloatingTabBar).evaluate().isNotEmpty) {
    await _tapCalendarTab(tester);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('앱 기본 동작 검증', () {
    testWidgets('앱 실행 및 캘린더 탭 표시', (tester) async {
      await _startFresh(tester);

      // 캘린더 화면이 기본으로 표시 (AppBar + 탭 라벨)
      expect(find.text(AppStrings.calendarTitle), findsWidgets);

      // 플로팅 탭바 + 3탭 라벨 확인
      expect(find.byType(FloatingTabBar), findsOneWidget);
      expect(find.text(AppStrings.tabSchedule), findsOneWidget);
      expect(find.text(AppStrings.settingsTitle), findsWidgets);
    });

    testWidgets('탭 전환: 캘린더 → 일정 → 설정', (tester) async {
      await _startFresh(tester);

      await _tapScheduleTab(tester);
      expect(find.text(AppStrings.scheduleTitle), findsWidgets);

      await _tapSettingsTab(tester);
      expect(find.text(AppStrings.settingsImportSection), findsOneWidget);

      await _tapCalendarTab(tester);
      expect(find.text(AppStrings.calendarTitle), findsWidgets);
    });

    testWidgets('캘린더 월 이동 (화살표 버튼)', (tester) async {
      await _startFresh(tester);

      // 현재 월 헤더 확인
      final now = DateTime.now();
      expect(find.textContaining('${now.year}년'), findsOneWidget);

      // 다음 달 이동
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // 이전 달 이동 (2번 → 원래 달 -1)
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
    });

    testWidgets('캘린더 이벤트 추가 바텀시트', (tester) async {
      await _startFresh(tester);

      await _tapAddFab(tester);

      // 추가 바텀시트 확인 (showModalBottomSheet)
      expect(find.text(AppStrings.calendarAddEvent), findsOneWidget);
      expect(find.text(AppStrings.calendarEventTitleHint), findsOneWidget);

      // 취소
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
    });

    testWidgets('일정 검토 빈 상태 표시', (tester) async {
      await _startFresh(tester);

      await _tapScheduleTab(tester);

      expect(find.text(AppStrings.scheduleEmpty), findsOneWidget);
    });

    testWidgets('설정 탭: 가져오기 인라인 섹션 + 전체 삭제 메뉴 노출', (tester) async {
      await _startFresh(tester);

      await _tapSettingsTab(tester);

      // 가져오기 섹션이 인라인으로 표시
      expect(find.text(AppStrings.settingsImportSection), findsOneWidget);
      expect(find.text(AppStrings.importSelectFile), findsOneWidget);

      // 데이터 관리 섹션 (fold 아래)
      await _scrollToInSettings(
        tester,
        find.text(AppStrings.settingsResetAll),
      );
      expect(find.text(AppStrings.settingsDataSection), findsOneWidget);
      expect(find.text(AppStrings.settingsResetAll), findsOneWidget);
    });

    testWidgets('전체 초기화 플로우: 이벤트 추가 → 초기화 → 사라짐 확인',
        (tester) async {
      await _startFresh(tester);

      // 1) 캘린더에 이벤트 추가
      await _tapAddFab(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        '콜드로드 테스트 이벤트',
      );
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();
      expect(find.text('콜드로드 테스트 이벤트'), findsWidgets);

      // 2) 설정 탭 → 전체 초기화
      await _tapSettingsTab(tester);
      await _scrollToInSettings(
        tester,
        find.text(AppStrings.settingsResetAll),
      );
      await tester.tap(find.text(AppStrings.settingsResetAll));
      await tester.pumpAndSettle();

      // 확인 다이얼로그
      expect(find.text(AppStrings.settingsResetAllConfirmTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.settingsResetAllConfirm));
      await tester.pumpAndSettle();

      // 성공 스낵바
      expect(find.text(AppStrings.settingsResetAllDone), findsOneWidget);

      // 3) 캘린더로 복귀 → 이벤트 사라짐
      await _tapCalendarTab(tester);
      expect(find.text('콜드로드 테스트 이벤트'), findsNothing);
      expect(find.text(AppStrings.calendarNoEvents), findsOneWidget);
    });

    testWidgets('초기화 취소: 다이얼로그에서 취소 시 데이터 유지', (tester) async {
      await _startFresh(tester);

      // 이벤트 추가
      await _tapAddFab(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        '취소 테스트 이벤트',
      );
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // 설정 탭 → 초기화 → 취소
      await _tapSettingsTab(tester);
      await _scrollToInSettings(
        tester,
        find.text(AppStrings.settingsResetAll),
      );
      await tester.tap(find.text(AppStrings.settingsResetAll));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();

      // 캘린더 복귀 → 이벤트 그대로
      await _tapCalendarTab(tester);
      expect(find.text('취소 테스트 이벤트'), findsWidgets);
    });

    testWidgets(
        '휴지통 플로우: 이벤트 추가 → 편집시트 휴지통으로 삭제 → 휴지통 확인 → 복구',
        (tester) async {
      await _startFresh(tester);

      // 1) 이벤트 추가
      await _tapAddFab(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        '휴지통 테스트 이벤트',
      );
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();
      expect(find.text('휴지통 테스트 이벤트'), findsOneWidget);

      // 2) 이벤트 탭 → 편집 시트 → 우상단 휴지통 아이콘
      await tester.tap(find.text('휴지통 테스트 이벤트'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.calendarEditEvent), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('휴지통 테스트 이벤트'), findsNothing);

      // 3) 설정 탭 → 휴지통 진입
      await _tapSettingsTab(tester);
      await _scrollToInSettings(
        tester,
        find.text(AppStrings.settingsTrashDescription),
      );
      await tester.tap(find.text(AppStrings.settingsTrashDescription));
      await tester.pumpAndSettle();

      // 4) 휴지통에 삭제한 이벤트 노출
      expect(find.text('휴지통 테스트 이벤트'), findsOneWidget);
      expect(find.textContaining(AppStrings.trashSectionEvents), findsWidgets);

      // 5) 복구
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.trashEmpty), findsOneWidget);

      // 6) 캘린더 복귀 → 이벤트 복원됨
      await _tapCalendarTab(tester);
      expect(find.text('휴지통 테스트 이벤트'), findsOneWidget);
    });

    testWidgets('완료 토글: 왼쪽 스와이프 → 체크 아이콘 표시 → 다시 스와이프 시 원상복구',
        (tester) async {
      await _startFresh(tester);

      // 이벤트 추가
      await _tapAddFab(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        '완료 테스트 이벤트',
      );
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // 힌트 바에도 check_circle이 있을 수 있으므로 count로 판정
      int checkCount() => find.byIcon(Icons.check_circle).evaluate().length;
      final initial = checkCount();

      // 왼쪽 스와이프 → 완료 토글
      await tester.drag(
        find.text('완료 테스트 이벤트'),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('완료 테스트 이벤트'), findsOneWidget);
      expect(checkCount(), initial + 1);

      // 다시 왼쪽 스와이프 → 완료 취소
      await tester.drag(
        find.text('완료 테스트 이벤트'),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(checkCount(), initial);
    });

    testWidgets('설정 탭: 알림 섹션 UI 노출 확인', (tester) async {
      await _startFresh(tester);

      await _tapSettingsTab(tester);

      // 섹션 헤더 / 마스터 스위치는 상단이라 스크롤 전에 확인
      expect(find.text(AppStrings.settingsNotificationSection), findsOneWidget);
      expect(find.text(AppStrings.settingsNotificationMaster), findsOneWidget);

      // 세부 항목/테스트 버튼까지 스크롤
      await _scrollToInSettings(
        tester,
        find.text(AppStrings.settingsNotificationTest),
      );

      expect(find.text(AppStrings.settingsNotificationMonthStart),
          findsOneWidget);
      expect(find.text(AppStrings.settingsNotificationWeekBefore),
          findsOneWidget);
      expect(find.text(AppStrings.settingsNotificationDayBefore),
          findsOneWidget);
      expect(find.text(AppStrings.settingsNotificationTest), findsOneWidget);
    });
  });
}
