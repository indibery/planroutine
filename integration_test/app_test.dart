import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';

/// 설정 탭 내부에서 target이 화면에 보일 때까지 스크롤한 뒤 다음 액션을 허용한다.
/// 설정 ListView가 알림/Google/휴지통/데이터관리/앱정보로 길어져 fold 아래 항목이
/// 기본 viewport에 없기 때문.
Future<void> _scrollToInSettings(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// 각 테스트를 깨끗한 상태(캘린더 탭 + 빈 DB)에서 시작시킨다.
/// appRouter / DatabaseHelper가 싱글톤이라 테스트 간 상태가 누적된다.
Future<void> _startFresh(WidgetTester tester) async {
  await DatabaseHelper.instance.resetAllData();
  await tester.pumpWidget(const ProviderScope(child: PlanRoutineApp()));
  await tester.pumpAndSettle();
  // 하단 탭의 캘린더 아이콘을 탭해 /calendar로 복귀
  // (AppBar 타이틀 "캘린더"와 탭 라벨 "캘린더"가 중복될 수 있어 아이콘으로 식별)
  final calendarTabIcon = find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.byIcon(Icons.calendar_month),
  );
  if (calendarTabIcon.evaluate().isNotEmpty) {
    await tester.tap(calendarTabIcon);
    await tester.pumpAndSettle();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('앱 기본 동작 검증', () {
    testWidgets('앱 실행 및 캘린더 탭 표시', (tester) async {
      await _startFresh(tester);

      // 캘린더 화면이 기본으로 표시 (AppBar + 탭 라벨로 2개)
      expect(find.text(AppStrings.calendarTitle), findsWidgets);

      // 하단 3탭 네비게이션 확인 (캘린더 / 일정 / 설정)
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text(AppStrings.tabSchedule), findsOneWidget);
      expect(find.text(AppStrings.settingsTitle), findsWidgets);
    });

    testWidgets('탭 전환: 캘린더 → 일정 → 설정', (tester) async {
      await _startFresh(tester);

      // 일정 탭으로 이동
      await tester.tap(find.text(AppStrings.tabSchedule));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.scheduleTitle), findsOneWidget);

      // 설정 탭으로 이동 (하단 탭 아이콘으로 식별)
      final settingsTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.settings),
      );
      await tester.tap(settingsTabIcon);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.settingsImportSection), findsOneWidget);

      // 다시 캘린더 탭으로 (아이콘으로 식별)
      final calendarTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.calendar_month),
      );
      await tester.tap(calendarTabIcon);
      await tester.pumpAndSettle();
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

    testWidgets('캘린더 이벤트 추가 다이얼로그', (tester) async {
      await _startFresh(tester);

      // FAB 버튼 탭
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 이벤트 추가 다이얼로그 확인
      expect(find.text(AppStrings.calendarAddEvent), findsOneWidget);
      expect(find.text(AppStrings.calendarEventTitleHint), findsOneWidget);

      // 취소
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
    });

    testWidgets('일정 검토 빈 상태 표시', (tester) async {
      await _startFresh(tester);

      // 일정 탭으로 이동
      await tester.tap(find.text(AppStrings.tabSchedule));
      await tester.pumpAndSettle();

      // 빈 상태 메시지 확인
      expect(find.text(AppStrings.scheduleEmpty), findsOneWidget);
    });

    testWidgets('설정 탭: 가져오기 인라인 섹션 + 전체 삭제 메뉴 노출', (tester) async {
      await _startFresh(tester);

      // 설정 탭 이동
      final settingsTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.settings),
      );
      await tester.tap(settingsTabIcon);
      await tester.pumpAndSettle();

      // 가져오기 섹션이 인라인으로 표시 (별도 화면 이동 없이 파일선택 버튼 노출)
      expect(find.text(AppStrings.settingsImportSection), findsOneWidget);
      expect(find.text(AppStrings.importSelectFile), findsOneWidget);

      // 데이터 관리 섹션 (fold 아래에 있을 수 있으므로 스크롤 후 검증)
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
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        '콜드로드 테스트 이벤트',
      );
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();
      expect(find.text('콜드로드 테스트 이벤트'), findsWidgets);

      // 2) 설정 탭 → 전체 초기화
      final settingsTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.settings),
      );
      await tester.tap(settingsTabIcon);
      await tester.pumpAndSettle();
      await _scrollToInSettings(
        tester,
        find.text(AppStrings.settingsResetAll),
      );
      await tester.tap(find.text(AppStrings.settingsResetAll));
      await tester.pumpAndSettle();

      // 확인 다이얼로그 표시
      expect(find.text(AppStrings.settingsResetAllConfirmTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.settingsResetAllConfirm));
      await tester.pumpAndSettle();

      // 성공 스낵바
      expect(find.text(AppStrings.settingsResetAllDone), findsOneWidget);

      // 3) 캘린더로 복귀 → 이벤트 사라짐
      final calendarTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.calendar_month),
      );
      await tester.tap(calendarTabIcon);
      await tester.pumpAndSettle();
      expect(find.text('콜드로드 테스트 이벤트'), findsNothing);
      expect(find.text(AppStrings.calendarNoEvents), findsOneWidget);
    });

    testWidgets('초기화 취소: 다이얼로그에서 취소 시 데이터 유지', (tester) async {
      await _startFresh(tester);

      // 이벤트 추가
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        '취소 테스트 이벤트',
      );
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // 설정 탭 → 초기화 → 취소
      final settingsTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.settings),
      );
      await tester.tap(settingsTabIcon);
      await tester.pumpAndSettle();
      await _scrollToInSettings(
        tester,
        find.text(AppStrings.settingsResetAll),
      );
      await tester.tap(find.text(AppStrings.settingsResetAll));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();

      // 캘린더 복귀 → 이벤트 그대로 존재
      final calendarTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.calendar_month),
      );
      await tester.tap(calendarTabIcon);
      await tester.pumpAndSettle();
      expect(find.text('취소 테스트 이벤트'), findsWidgets);
    });

    testWidgets(
        '휴지통 플로우: 이벤트 추가 → 편집시트 휴지통으로 삭제 → 휴지통 확인 → 복구',
        (tester) async {
      await _startFresh(tester);

      // 1) 이벤트 추가
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        '휴지통 테스트 이벤트',
      );
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();
      expect(find.text('휴지통 테스트 이벤트'), findsOneWidget);

      // 2) 이벤트 탭 → 편집 시트 열림 → 우상단 휴지통 아이콘으로 soft-delete
      await tester.tap(find.text('휴지통 테스트 이벤트'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.calendarEditEvent), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('휴지통 테스트 이벤트'), findsNothing);

      // 3) 설정 탭 → 휴지통 진입
      final settingsTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.settings),
      );
      await tester.tap(settingsTabIcon);
      await tester.pumpAndSettle();
      await _scrollToInSettings(
        tester,
        find.text(AppStrings.settingsTrashDescription),
      );
      await tester.tap(find.text(AppStrings.settingsTrashDescription));
      await tester.pumpAndSettle();

      // 4) 휴지통에 삭제한 이벤트가 보여야 함
      expect(find.text('휴지통 테스트 이벤트'), findsOneWidget);
      expect(find.textContaining(AppStrings.trashSectionEvents), findsWidgets);

      // 5) 복구 버튼 탭
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.trashEmpty), findsOneWidget);

      // 6) 캘린더 돌아가면 이벤트 복구됨
      final calendarTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.calendar_month),
      );
      await tester.tap(calendarTabIcon);
      await tester.pumpAndSettle();
      expect(find.text('휴지통 테스트 이벤트'), findsOneWidget);
    });

    testWidgets('완료 토글: 왼쪽 스와이프 → 체크 아이콘 표시 → 다시 스와이프 시 원상복구',
        (tester) async {
      await _startFresh(tester);

      // 이벤트 추가
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        '완료 테스트 이벤트',
      );
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // 힌트 바에도 check_circle이 있으므로 count로 판정
      // (힌트 바가 숨김 상태/표시 상태 어느 쪽이든 toggle 전후 1개씩 변하는 게 핵심)
      int checkCount() => find.byIcon(Icons.check_circle).evaluate().length;
      final initial = checkCount();

      // 왼쪽 스와이프 → 완료 토글
      await tester.drag(
        find.text('완료 테스트 이벤트'),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      // 목록에는 유지 (dismiss 취소, 액션만 수행)
      expect(find.text('완료 테스트 이벤트'), findsOneWidget);
      // 체크 아이콘 1개 추가
      expect(checkCount(), initial + 1);

      // 다시 왼쪽 스와이프 → 완료 취소
      await tester.drag(
        find.text('완료 테스트 이벤트'),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      // 체크 아이콘 원래 수로 복귀
      expect(checkCount(), initial);
    });

    testWidgets('설정 탭: 알림 섹션 UI 노출 확인', (tester) async {
      await _startFresh(tester);

      final settingsTabIcon = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.settings),
      );
      await tester.tap(settingsTabIcon);
      await tester.pumpAndSettle();

      // 알림 섹션은 가려질 수 있으니 "테스트 알림" 버튼까지 스크롤
      await _scrollToInSettings(
        tester,
        find.text(AppStrings.settingsNotificationTest),
      );

      // 알림 섹션 헤더 + 마스터 + 3 세부 + 테스트 버튼 모두 노출
      expect(find.text(AppStrings.settingsNotificationSection), findsOneWidget);
      expect(find.text(AppStrings.settingsNotificationMaster), findsOneWidget);
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
