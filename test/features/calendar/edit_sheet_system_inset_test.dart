// 편집 시트의 저장·취소 버튼은 **시스템 내비게이션 바에 가리지 않는다.**
//
// 실기기(Android)에서 신고됐다 — 일정 추가 시트를 열고 아직 아무 칸도 누르지
// 않아 키보드가 없는 상태에서, 저장·취소 버튼이 화면 맨 아래 시스템 바에
// 절반쯤 덮였다(2026-08-06).
//
// **원인은 여백이 인셋을 한 종류만 봤다는 것이다.** 두 시트는 아래 여백을
// `max(0, viewInsets.bottom)`으로 줬는데 `viewInsets`는 **키보드**다.
// 키보드가 올라오면 그 값이 내비게이션 바 높이까지 포함해 함께 밀어내지만,
// 키보드가 없으면 `0`이 되어 여백이 통째로 사라진다. 시스템 바는
// `viewPadding`이라 그때 아무도 보지 않는다.
//
// `showModalBottomSheet`의 `useSafeArea`가 기본 `false`라 시트가 시스템 바
// 아래까지 뻗는 것이 전제다 — 그래서 시트가 스스로 그 높이를 비켜야 한다.
//
// 음수 클램프(`max(0, ...)`)는 그대로 지킨다 — 별도 가드가 있다
// (`*_negative_inset_test.dart`). 두 가드는 같은 식을 서로 다른 이유로 지킨다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_edit_sheet.dart';
import 'package:planroutine/shared/widgets/gold_gradient_button.dart';

/// Pixel 7 급 — 3버튼 내비게이션 바가 48dp다. 제스처 바(24dp)보다 크게 잡아
/// 더 나쁜 쪽을 검사한다.
const _dpr = 3.0;
const _screenH = 874.0;
const _navBar = 48.0;

/// 키보드 없음 + 시스템 내비게이션 바 있음 — 신고된 상태 그대로.
void _applyNavBarOnly(WidgetTester tester) {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = const Size(402 * _dpr, _screenH * _dpr);
  tester.view.viewInsets = const FakeViewPadding(); // 키보드 내려감
  tester.view.viewPadding = const FakeViewPadding(bottom: _navBar * _dpr);
  tester.view.padding = const FakeViewPadding(bottom: _navBar * _dpr);
}

/// 버튼 아래쪽 경계가 시스템 바 위에 있는지.
///
/// **라벨(`find.text`)이 아니라 버튼 상자를 잰다.** 상자가 라벨보다 아래로 더
/// 뻗으므로, 라벨만 재면 글자는 보이는데 누를 곳이 가린 상태를 통과시킨다 —
/// 실기기에서 "절반쯤 가림"으로 보인 것이 정확히 그 차이다.
void _expectClearsNavBar(WidgetTester tester, Finder button, String which) {
  final bottom = tester.getRect(button).bottom;
  const limit = _screenH - _navBar;
  expect(
    bottom,
    lessThanOrEqualTo(limit),
    reason:
        '$which 버튼의 아래 경계가 $bottom 인데 시스템 바가 $limit 부터 시작한다 — '
        '${(bottom - limit).toStringAsFixed(1)}pt 가린다. '
        '아래 여백이 viewInsets(키보드)만 보고 viewPadding(시스템 바)을 안 봤다',
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  testWidgets('일정 추가 시트 — 키보드가 없어도 버튼이 시스템 바를 비킨다', (tester) async {
    _applyNavBarOnly(tester);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EventEditDialog.show(
                  context,
                  initialDate: DateTime(2026, 8, 6),
                  allowKindChange: false,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheet = find.byType(EventEditDialog);
    _expectClearsNavBar(
      tester,
      find.descendant(of: sheet, matching: find.byType(GoldGradientButton)),
      '저장',
    );
    _expectClearsNavBar(
      tester,
      find.descendant(of: sheet, matching: find.byType(OutlinedButton)),
      '취소',
    );
  });

  testWidgets('일정 수정 시트(입력 탭) — 키보드가 없어도 버튼이 시스템 바를 비킨다', (tester) async {
    _applyNavBarOnly(tester);
    addTearDown(tester.view.reset);

    const schedule = Schedule(title: '학부모 총회 안내장', scheduledDate: '2026-08-06');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScheduleEditSheet.show(context, schedule),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 하네스의 'open'도 ElevatedButton이라 시트 안으로 좁힌다.
    final sheet = find.byType(ScheduleEditSheet);
    _expectClearsNavBar(
      tester,
      find.descendant(of: sheet, matching: find.byType(ElevatedButton)),
      '저장',
    );
    _expectClearsNavBar(
      tester,
      find.descendant(of: sheet, matching: find.byType(OutlinedButton)),
      '취소',
    );
  });
}
