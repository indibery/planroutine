import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/app.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/utils/date_utils.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';

/// 설정 탭 내부에서 target이 화면에 보일 때까지 스크롤한 뒤 다음 액션을 허용한다.
/// 설정 ListView가 알림/휴지통/데이터관리/앱정보로 길어져 fold 아래 항목이
/// 기본 viewport에 없기 때문. 탭바는 Scaffold bottomNavigationBar로 body 바깥에
/// 있지만, scrollUntilVisible의 기본 drag 시작점이 항목 위에 걸치는 경우가 있어
/// 상단 근처에서 수동 drag 로 스크롤한다.
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

/// Dismissible 왼쪽(endToStart) 스와이프를 결정적으로 수행한다.
/// tester.drag는 rebuild 직후 두 번째 스와이프가 임계값을 못 넘겨 누락되는 경우가
/// 있어, 명시적 gesture(down→move→pump→up)로 임계값을 확실히 넘긴다.
Future<void> _swipeLeft(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  // 실제 드래그처럼 점진적으로 이동해야 Dismissible 임계값이 안정적으로 넘어간다.
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(const Offset(-45, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
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
      expect(find.text(CalendarStrings.title), findsWidgets);

      // 플로팅 탭바 + 3탭 라벨 확인
      expect(find.byType(FloatingTabBar), findsOneWidget);
      expect(find.text(AppStrings.tabSchedule), findsOneWidget);
      expect(find.text(SettingsStrings.title), findsWidgets);
    });

    testWidgets('탭 전환: 캘린더 → 일정 → 설정', (tester) async {
      await _startFresh(tester);

      await _tapScheduleTab(tester);
      expect(find.text(ScheduleStrings.title), findsWidgets);

      await _tapSettingsTab(tester);
      // '일정 가져오기'는 섹션 헤더 + 진입 타일 양쪽에 나타나므로 findsWidgets.
      expect(find.text(SettingsStrings.importSection), findsWidgets);

      await _tapCalendarTab(tester);
      expect(find.text(CalendarStrings.title), findsWidgets);
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
      expect(find.text(CalendarStrings.addEvent), findsOneWidget);
      expect(find.text(CalendarStrings.eventTitleHint), findsOneWidget);

      // 취소
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
    });

    testWidgets('일정 검토 빈 상태 표시', (tester) async {
      await _startFresh(tester);

      await _tapScheduleTab(tester);

      expect(find.text(ScheduleStrings.empty), findsOneWidget);
    });

    testWidgets('설정 탭: 가져오기 인라인 섹션 + 전체 삭제 메뉴 노출', (tester) async {
      await _startFresh(tester);

      await _tapSettingsTab(tester);

      // 가져오기 섹션 노출 — 헤더 + /import로 진입하는 업로드 타일.
      // (파일 선택 UI는 이제 push된 ImportScreen 안에 있어 설정 탭엔 없다)
      expect(find.text(SettingsStrings.importSection), findsWidgets);
      expect(find.byIcon(Icons.upload_file), findsOneWidget);

      // 데이터 관리 섹션 (fold 아래)
      await _scrollToInSettings(
        tester,
        find.text(SettingsStrings.resetAll),
      );
      expect(find.text(SettingsStrings.dataSection), findsOneWidget);
      expect(find.text(SettingsStrings.resetAll), findsOneWidget);
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
        find.text(SettingsStrings.resetAll),
      );
      await tester.tap(find.text(SettingsStrings.resetAll));
      await tester.pumpAndSettle();

      // 확인 다이얼로그
      expect(find.text(SettingsStrings.resetAllConfirmTitle), findsOneWidget);
      await tester.tap(find.text(SettingsStrings.resetAllConfirm));
      await tester.pumpAndSettle();

      // 성공 스낵바
      expect(find.text(SettingsStrings.resetAllDone), findsOneWidget);

      // 3) 캘린더로 복귀 → 이벤트 사라짐
      await _tapCalendarTab(tester);
      expect(find.text('콜드로드 테스트 이벤트'), findsNothing);
      expect(find.text(CalendarStrings.noEvents), findsOneWidget);
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
        find.text(SettingsStrings.resetAll),
      );
      await tester.tap(find.text(SettingsStrings.resetAll));
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
      expect(find.text(CalendarStrings.editEvent), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('휴지통 테스트 이벤트'), findsNothing);

      // 3) 설정 탭 → 휴지통 진입
      // 섹션 subtitle은 탭 대상이 아니므로, 실제 진입 타일(ListTile)을 탭한다.
      await _tapSettingsTab(tester);
      final trashTile = find.widgetWithText(ListTile, TrashStrings.title);
      await _scrollToInSettings(tester, trashTile);
      await tester.tap(trashTile);
      await tester.pumpAndSettle();

      // 4) 휴지통에 삭제한 이벤트 노출
      expect(find.text('휴지통 테스트 이벤트'), findsOneWidget);
      expect(find.textContaining(TrashStrings.sectionEvents), findsWidgets);

      // 5) 복구
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();
      expect(find.text(TrashStrings.empty), findsOneWidget);

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

      // 완료 표시는 이벤트 카드 안 trailing 아이콘(check_circle, size 18)뿐.
      // 힌트바/스와이프 배경의 check_circle과 섞이지 않도록 size로 정밀 판정.
      Finder doneMark() => find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.check_circle && w.size == 18,
          );
      expect(doneMark(), findsNothing);

      // 왼쪽 스와이프 → 완료 토글
      await _swipeLeft(tester, find.text('완료 테스트 이벤트'));
      expect(find.text('완료 테스트 이벤트'), findsOneWidget);
      expect(doneMark(), findsOneWidget);

      // 다시 왼쪽 스와이프 → 완료 취소
      await _swipeLeft(tester, find.text('완료 테스트 이벤트'));
      expect(doneMark(), findsNothing);
    });

    testWidgets('중요 표시: 편집에서 토글 → 저장 → 목록에 ★ 중요 배지', (tester) async {
      await _startFresh(tester);

      // 이벤트 추가
      await _tapAddFab(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        '중요 테스트 이벤트',
      );
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // 편집 진입 → 중요 토글 ON → 저장
      await tester.tap(find.text('중요 테스트 이벤트'));
      await tester.pumpAndSettle();
      expect(find.text(CalendarStrings.importantLabel), findsOneWidget);
      await tester.tap(find.byKey(const Key('important_toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // 목록에 ★ 중요 배지 노출
      expect(find.text(CalendarStrings.importantBadge), findsOneWidget);
    });

    testWidgets('날짜 점프: 이번 달 말일 근처 셀을 탭하면 그 이벤트가 목록에 보인다',
        (tester) async {
      // 실기기 재현: 캘린더가 위를 차지해 목록 뷰포트가 좁을 때, 뒤쪽 날짜(말일)를
      // 탭해도 목록이 그 날짜로 스크롤되는지 검증.
      await DatabaseHelper.instance.resetAllData();
      final repo = CalendarRepository(dbHelper: DatabaseHelper.instance);
      final now = DateTime.now();
      // 이번 달 1일부터 28일까지 여러 날짜에 이벤트를 심어 목록을 길게 만든다.
      for (final day in [1, 4, 8, 12, 16, 20, 24, 28]) {
        final date = DateTime(now.year, now.month, day);
        await repo.createEvent(CalendarEvent(
          title: '점프테스트 $day일',
          eventDate: formatDate(date),
        ));
      }

      await tester.pumpWidget(const ProviderScope(child: PlanRoutineApp()));
      await tester.pumpAndSettle();
      if (find.byType(FloatingTabBar).evaluate().isNotEmpty) {
        await _tapCalendarTab(tester);
      }

      // 그리드엔 이전 달 흐린 28(첫 줄)과 이번 달 28이 함께 있다. 아래쪽(y 큰)이
      // 이번 달 28이므로 그것을 탭한다.
      final cells = find.text('28').evaluate().toList()
        ..sort((a, b) => tester
            .getCenter(find.byWidget(a.widget))
            .dy
            .compareTo(tester.getCenter(find.byWidget(b.widget)).dy));
      await tester.tap(find.byWidget(cells.last.widget));
      await tester.pumpAndSettle();

      // 28일 이벤트가 목록 뷰포트 안으로 스크롤되어 보여야 한다.
      final finder = find.text('점프테스트 28일');
      expect(finder, findsOneWidget);
      final screenH =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final top = tester.getTopLeft(finder).dy;
      expect(top, greaterThanOrEqualTo(0));
      expect(top, lessThan(screenH),
          reason: '28일 이벤트가 화면 밖(아래)에 있음 → 스크롤 안 됨. top=$top, screenH=$screenH');
    });

    testWidgets('화면 테마: 밝게 선택 시 앱이 크림 배경으로 전환', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _startFresh(tester);
      await _tapSettingsTab(tester);

      // 먼저 어둡게로 고정한 뒤 밝게로 전환 — 다크→라이트에서 텍스트 색이
      // 이전(밝은) 값으로 남던 버그 회귀 방지.
      expect(find.text(SettingsStrings.themeLabel), findsOneWidget);
      await tester.tap(find.text(SettingsStrings.themeDark));
      await tester.pumpAndSettle();

      // 밝게로 전환
      await tester.tap(find.text(SettingsStrings.themeLight));
      await tester.pumpAndSettle();

      // AppBar 제목 '설정' 텍스트가 라이트 본문색(ink #17253D)로 갱신돼야 한다.
      // (탭 라벨에도 '설정'이 있으므로 AppBar 안의 것으로 특정)
      final titleColor = tester
          .widget<Text>(find.descendant(
            of: find.byType(AppBar),
            matching: find.text(SettingsStrings.title),
          ))
          .style
          ?.color;
      expect(titleColor, const Color(0xFF17253D),
          reason: '다크→라이트 후 제목이 라이트 ink로 갱신');

      // Scaffold 배경이 라이트 팔레트로 바뀌어야 한다.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final ctx = tester.element(find.byType(Scaffold).first);
      final bg = scaffold.backgroundColor ??
          Theme.of(ctx).scaffoldBackgroundColor;
      expect(bg, const Color(0xFFF6F8FB), reason: '라이트 쿨 미스트 배경');

      // 하단 탭바도 함께 라이트(surface=흰색)로 바뀌어야 한다.
      // (ShellRoute 탭바가 테마 변경 시 리빌드 안 되던 버그 회귀 방지)
      Color tabBarColor() {
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(FloatingTabBar),
                matching: find.byType(Container),
              )
              .first,
        );
        return (container.decoration as BoxDecoration).color!;
      }

      expect(tabBarColor(), const Color(0xFFFFFFFF),
          reason: '라이트 탭바 배경(surface=흰색)');

      // 다시 어둡게 → 네이비 복귀 (배경 + 탭바 둘 다)
      await tester.tap(find.text(SettingsStrings.themeDark));
      await tester.pumpAndSettle();
      final ctx2 = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(ctx2).scaffoldBackgroundColor, const Color(0xFF0A1628),
          reason: '다크 네이비 배경');
      expect(tabBarColor(), const Color(0xFF142847),
          reason: '다크 탭바 배경(navyMid)');
    });

    testWidgets('설정 탭: 알림 섹션 UI 노출 확인', (tester) async {
      await _startFresh(tester);

      await _tapSettingsTab(tester);

      // 섹션 헤더 / 마스터 스위치는 상단이라 스크롤 전에 확인
      expect(find.text(NotificationStrings.section), findsOneWidget);
      expect(find.text(NotificationStrings.master), findsOneWidget);

      // 월초/1주 전/1일 전/테스트는 '고급' ExpansionTile 안에 접혀 있으므로 먼저 펼친다.
      await _scrollToInSettings(
        tester,
        find.text(NotificationStrings.advanced),
      );
      await tester.tap(find.text(NotificationStrings.advanced));
      await tester.pumpAndSettle();

      // 펼친 뒤 세부 항목/테스트 버튼까지 스크롤
      await _scrollToInSettings(
        tester,
        find.text(NotificationStrings.test),
      );

      expect(find.text(NotificationStrings.monthStart),
          findsOneWidget);
      expect(find.text(NotificationStrings.weekBefore),
          findsOneWidget);
      expect(find.text(NotificationStrings.dayBefore),
          findsOneWidget);
      expect(find.text(NotificationStrings.test), findsOneWidget);
    });

    testWidgets('AI로 보내기: 실제 share 호출이 예외 없이 네이티브 시트를 띄운다',
        (tester) async {
      // 고급 토글 ON (실제 SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ai_task_share_enabled', true);
      await _startFresh(tester);

      // 이벤트 하나 추가
      await _tapAddFab(tester);
      await tester.enterText(
          find.byType(TextFormField).first, 'AI 공유 테스트');
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // 편집 다이얼로그 → AI로 보내기 (mock 없이 실제 share_plus 채널)
      await tester.tap(find.text('AI 공유 테스트'));
      await tester.pumpAndSettle();
      expect(find.text('AI로 보내기'), findsOneWidget);

      await tester.tap(find.text('AI로 보내기'));
      // 네이티브 시트 표시 대기 — 여기서 PlatformException이 나면 테스트가 실패한다
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AI 사진 가져오기: 붙여넣기 → 미리보기 → 등록 → 검토 대기 노출',
        (tester) async {
      await _startFresh(tester);

      // 일정 탭 AppBar 가져오기 아이콘으로 진입 (신규 진입점 검증)
      await _tapScheduleTab(tester);
      await tester.tap(find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.file_download_outlined),
      ));
      await tester.pumpAndSettle();

      // AI 섹션 노출 확인 (필요 시 스크롤)
      final aiPaste = find.text(ImportStrings.aiPaste);
      await _scrollToInSettings(tester, aiPaste);
      expect(find.text(ImportStrings.aiCopyPrompt), findsOneWidget);

      // AI 응답을 클립보드에 준비 (실기기/시뮬 실제 클립보드).
      // 실기기 검증에서 GPT 출력이 스마트 따옴표로 복사돼 실패했던 형태 그대로 사용.
      await Clipboard.setData(const ClipboardData(
        text: '결과입니다.\n```json\n'
            '[{“title”:“입학식”,“date”:“2026-03-02”},'
            '{“title”:“봄 현장체험학습”,“date”:“2026-04-24”,“description”:“4-6학년”}]'
            '\n```',
      ));

      // 붙여넣기 → 미리보기 시트
      await tester.tap(aiPaste);
      await tester.pumpAndSettle();
      expect(find.text(ImportStrings.aiPreviewTitle), findsOneWidget);
      expect(find.text('입학식'), findsOneWidget);

      // 등록 → 시트 닫힘
      await tester.tap(find.text(ImportStrings.aiRegisterButton(2)));
      await tester.pumpAndSettle();

      // 일정 탭에서 검토 대기로 보이는지 (/import는 ShellRoute 안이라 탭바 유지)
      await _tapScheduleTab(tester);
      expect(find.text('입학식'), findsOneWidget);
      expect(find.text('봄 현장체험학습'), findsOneWidget);
    });
  });
}
