import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';

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

      // 데이터 관리 섹션
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
  });
}
