import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_strings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('앱 기본 동작 검증', () {
    testWidgets('앱 실행 및 캘린더 탭 표시', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: PlanRoutineApp()),
      );
      await tester.pumpAndSettle();

      // 캘린더 화면이 기본으로 표시 (AppBar + 탭 라벨로 2개)
      expect(find.text(AppStrings.calendarTitle), findsWidgets);

      // 하단 3탭 네비게이션 확인
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text(AppStrings.tabSchedule), findsOneWidget);
      expect(find.text(AppStrings.tabImport), findsOneWidget);
    });

    testWidgets('탭 전환: 캘린더 → 일정 → 가져오기', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: PlanRoutineApp()),
      );
      await tester.pumpAndSettle();

      // 일정 탭으로 이동
      await tester.tap(find.text(AppStrings.tabSchedule));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.scheduleTitle), findsOneWidget);

      // 가져오기 탭으로 이동
      await tester.tap(find.text(AppStrings.tabImport));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.importTitle), findsOneWidget);

      // 다시 캘린더 탭으로
      await tester.tap(find.text(AppStrings.tabCalendar));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.calendarTitle), findsWidgets);
    });

    testWidgets('캘린더 월 이동 (화살표 버튼)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: PlanRoutineApp()),
      );
      await tester.pumpAndSettle();

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
      await tester.pumpWidget(
        const ProviderScope(child: PlanRoutineApp()),
      );
      await tester.pumpAndSettle();

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
      await tester.pumpWidget(
        const ProviderScope(child: PlanRoutineApp()),
      );
      await tester.pumpAndSettle();

      // 일정 탭으로 이동
      await tester.tap(find.text(AppStrings.tabSchedule));
      await tester.pumpAndSettle();

      // 빈 상태 메시지 확인
      expect(find.text(AppStrings.scheduleEmpty), findsOneWidget);
    });

    testWidgets('가져오기 초기 화면 표시', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: PlanRoutineApp()),
      );
      await tester.pumpAndSettle();

      // 가져오기 탭으로 이동
      await tester.tap(find.text(AppStrings.tabImport));
      await tester.pumpAndSettle();

      // 초기 화면 확인
      expect(find.text(AppStrings.importSelectFile), findsOneWidget);
      expect(find.byIcon(Icons.upload_file), findsWidgets);
    });
  });
}
