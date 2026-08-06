// 일정 시트의 **성격 카드는 한 줄**이고, 좁은 폭에서도 넘치지 않는다.
//
// 키보드가 올라오면 시트가 화면을 다 쓰고, 그 뒤로는 저장·취소가
// `SingleChildScrollView` 안에서 키보드 밑으로 밀린다(실기기 신고 2026-08-06,
// 실측: 키보드 380dp에서 35dp 가림). 종류 세그먼트와 중요 스위치를 한 줄로 합쳐
// 약 56dp를 회수해 그 임계값을 올렸다.
//
// ⚠️ **구조적 해결이 아니다** — 더 큰 키보드·큰 글꼴·필드 추가로 다시 깨질 수 있다.
// 그때의 다음 수순은 버튼을 스크롤 밖 고정 푸터로 빼는 것이다. 이 가드는 회수한
// 높이가 **다시 늘어나는 것**을 막는다(행이 둘로 갈라지면 깨진다).
//
// 폭을 훑는 이유: 합친 줄에 아이콘·세그먼트 2개·별·스위치가 함께 들어가 가로가
// 빠듯하다. 폭 하나로만 재면 다른 폭에서 조용히 넘친다
// (`bus_slot_tile_long_name_test`와 같은 이유).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  required double widthDp,
  double keyboardDp = 0,
  bool allowKindChange = true,
}) async {
  const dpr = 2.625;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(widthDp * dpr, 891 * dpr);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardDp * dpr);
  tester.view.viewPadding = const FakeViewPadding(bottom: 24 * dpr);
  tester.view.padding = FakeViewPadding(
    bottom: keyboardDp > 0 ? 0 : 24 * dpr,
  );
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
                allowKindChange: allowKindChange,
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

void main() {
  setUpAll(() async => initializeDateFormatting('ko_KR', null));

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('${width.toInt()}pt — 종류와 중요가 한 줄이고 넘치지 않는다',
        (tester) async {
      await _openSheet(tester, widthDp: width);

      expect(tester.takeException(), isNull,
          reason: '$width pt에서 성격 카드 행이 가로로 넘쳤다');

      final kind = find.byKey(const Key('kind_selector'));
      final important = find.byKey(const Key('important_toggle'));
      expect(kind, findsOneWidget);
      expect(important, findsOneWidget);

      // **같은 줄에 있다** — 세로 중심이 겹치면 한 행이다. 둘로 갈라지면 실패한다.
      final kindRect = tester.getRect(kind);
      final importantRect = tester.getRect(important);
      expect(
        (kindRect.center.dy - importantRect.center.dy).abs(),
        lessThan(8),
        reason: '종류(${kindRect.center.dy})와 중요(${importantRect.center.dy})가 '
            '다른 줄에 있다 — 합쳐서 회수한 높이가 도로 늘어났다',
      );
    });
  }

  testWidgets('글자 라벨이 사라진 자리를 스크린리더 이름이 잇는다', (tester) async {
    await _openSheet(tester, widthDp: 390);

    // `중요 표시` 텍스트는 지웠지만 이름은 남아야 한다.
    expect(find.text(CalendarStrings.importantLabel), findsNothing,
        reason: '한 줄로 합치며 글자 라벨은 뺐다');
    expect(
      find.bySemanticsLabel(CalendarStrings.importantLabel),
      findsOneWidget,
      reason: '글자를 없앴으면 Semantics로 이름을 남겨야 한다',
    );
  });

  testWidgets('오늘 탭 경로(종류 잠금)는 중요 표시만 글자 라벨과 함께 남는다',
      (tester) async {
    await _openSheet(tester, widthDp: 390, allowKindChange: false);

    expect(find.byKey(const Key('kind_selector')), findsNothing,
        reason: '오늘 탭에서는 종류를 바꿀 수 없다');
    expect(find.byKey(const Key('important_toggle')), findsOneWidget);
    expect(find.text(CalendarStrings.importantLabel), findsOneWidget,
        reason: '이 경로는 한 줄뿐이라 글자 라벨을 유지한다');
  });

  testWidgets('종류를 바꾸면 선택이 반영된다 (합치면서 동작을 잃지 않았다)',
      (tester) async {
    await _openSheet(tester, widthDp: 390);

    await tester.tap(find.text(EntryKind.event.label));
    await tester.pumpAndSettle();

    final segmented =
        tester.widget<SegmentedButton<EntryKind>>(find.byKey(const Key('kind_selector')));
    expect(segmented.selected, {EntryKind.event});
  });
}
