import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_edit_sheet.dart';
import 'package:planroutine/shared/widgets/keyboard_inset.dart';

/// 입력 탭 편집 시트도 포커스 전환에 흔들리지 않아야 한다.
///
/// 캘린더 시트(`event_edit_dialog_focus_jump_test.dart`)와 **같은 결함**이었다 —
/// 여백을 `viewInsets`에 1:1로 묶으면 제목 ↔ 설명 전환 때 iOS가 키보드를 내렸다
/// 올리며 시트가 통째로 움직인다. 이 시트도 제목+설명 두 칸 구조라 같이 걸린다.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScheduleEditSheet.show(
                  context,
                  const Schedule(
                    id: 1,
                    title: '학사일정 협의',
                    scheduledDate: '2026-03-02',
                  ),
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
  }

  testWidgets('포커스를 쥔 채 키보드 인셋이 잠깐 무너져도 시트가 움직이지 않는다',
      (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    addTearDown(tester.view.reset);
    const keyboard = 335.0;

    await open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();

    final header = find.text('일정 수정');
    await tester.tap(find.byType(TextField).at(0));
    await tester.pumpAndSettle();
    final settled = tester.getTopLeft(header).dy;

    // 포커스 전환 순간의 일시적 붕괴
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(
      tester.getTopLeft(header).dy,
      moreOrLessEquals(settled, epsilon: 1.0),
      reason: '포커스를 쥔 동안에는 키보드 자리를 내주지 않아야 한다',
    );
  });

  testWidgets('키보드만 내려가면(뒤로 키) 유예 뒤 자리를 돌려준다', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    addTearDown(tester.view.reset);
    const keyboard = 335.0;

    await open(tester);
    final header = find.text('일정 수정');
    final noKeyboard = tester.getTopLeft(header).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).at(0));
    await tester.pumpAndSettle();

    tester.view.viewInsets = FakeViewPadding.zero;
    // 먼저 한 프레임 — 이때 build가 유예 타이머를 건다. 대기 중인 Timer는
    // 프레임을 예약하지 않으므로 `pumpAndSettle`만으로는 시간이 흐르지 않는다.
    await tester.pump();
    await tester.pump(KeyboardInset.grace);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(header).dy,
      moreOrLessEquals(noKeyboard, epsilon: 1.0),
      reason: '버튼 아래 빈 공간이 남으면 안 된다',
    );
  });
}
