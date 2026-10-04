import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_arrival_card.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_tile.dart';
import 'package:planroutine/features/settings/presentation/widgets/stamp_style_sheet.dart';
import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/shared/widgets/slide_hint_bar.dart';

/// 화면마다 누를 수 있는 것이 **이름 있는 버튼**으로 읽히는지 본다.
///
/// 시뮬레이터 자동화(`snapshot_ui`·mobile MCP)는 이 이름으로 찾아 누른다. 소스 가드
/// (`button_semantics_guard_test`)는 `ButtonSemantics`로 감쌌는지만 보므로, 이름이 화면과
/// 맞는지는 여기서 본다(verifier가 짚은 빈 곳, 2026-10-04).
void main() {
  setUpAll(() async => initializeDateFormatting('ko_KR', null));

  Finder button(String label) => find.bySemanticsLabel(label);

  void expectButton(WidgetTester tester, String label, {bool? selected}) {
    expect(
      tester.getSemantics(button(label)),
      isSemantics(isButton: true, hasTapAction: true, isSelected: selected),
      reason: label,
    );
  }

  group('버스 카드', () {
    testWidgets('정류장 선택·방향 전환이 버튼이고 시맨틱스 탭이 콜백을 부른다', (tester) async {
      final handle = tester.ensureSemantics();
      var registered = 0;
      var flipped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusArrivalCard(
              view: const BusCardView(
                state: BusCardState.noStop,
                visible: [],
                hiddenCount: 0,
                fetchedAt: null,
              ),
              style: BusCardStyle.text,
              direction: CommuteDirection.toHome,
              stopName: '',
              expanded: true,
              onToggleExpanded: null,
              onFlipDirection: () => flipped++,
              onRegister: () => registered++,
            ),
          ),
        ),
      );

      final flip = BusStrings.flip(CommuteDirection.toHome.otherLabel);
      expectButton(tester, BusStrings.emptyNoStopAction);
      expectButton(tester, flip);
      tester.semantics.tap(
        find.semantics.byLabel(BusStrings.emptyNoStopAction),
      );
      tester.semantics.tap(find.semantics.byLabel(flip));
      expect((registered, flipped), (1, 1));
      handle.dispose();
    });

    testWidgets('제목줄은 방향·정류장·접기/펼치기를 담은 버튼이다', (tester) async {
      final handle = tester.ensureSemantics();
      var toggled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusArrivalCard(
              view: const BusCardView(
                state: BusCardState.closed,
                visible: [],
                hiddenCount: 0,
                fetchedAt: null,
              ),
              style: BusCardStyle.text,
              direction: CommuteDirection.toWork,
              stopName: '서울역버스환승센터',
              expanded: true,
              onToggleExpanded: () => toggled++,
              onFlipDirection: () {},
              onRegister: () {},
            ),
          ),
        ),
      );

      final header =
          '${CommuteDirection.toWork.title}, 서울역버스환승센터, ${BusStrings.collapse}';
      expectButton(tester, header);
      tester.semantics.tap(find.semantics.byLabel(header));
      expect(toggled, 1);
      handle.dispose();
    });
  });

  testWidgets('입력 탭 검토 행은 종류·제목·날짜를 담은 버튼이다', (tester) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleTile(
            schedule: const Schedule(
              id: 1,
              title: '운동회 준비 회의',
              scheduledDate: '2026-10-12',
              kind: EntryKind.event,
            ),
            onConfirm: () {},
            onDelete: () {},
            onTap: () => opened++,
          ),
        ),
      ),
    );

    const label = '행사, 운동회 준비 회의, 2026.10.12 (월)';
    expectButton(tester, label);
    tester.semantics.tap(find.semantics.byLabel(label));
    expect(opened, 1);
    handle.dispose();
  });

  testWidgets('도장 모양 시트의 선택지는 이름과 선택 상태를 가진 버튼이다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => StampStyleSheet.show(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    for (final style in SealStyle.values) {
      expectButton(
        tester,
        style.label,
        selected: style == StampSettings.defaults.style,
      );
    }
    handle.dispose();
  });

  testWidgets('안내 바의 닫기는 이름 있는 버튼이다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SlideHintBar(
              prefKey: 'test_hint',
              leftIcon: Icons.check,
              leftText: '오른쪽으로 밀기',
              leftColor: Colors.green,
              rightIcon: Icons.delete,
              rightText: '왼쪽으로 밀기',
              rightColor: Colors.red,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expectButton(tester, AppStrings.dismissHint);
    tester.semantics.tap(find.semantics.byLabel(AppStrings.dismissHint));
    await tester.pumpAndSettle();
    expect(
      button(AppStrings.dismissHint),
      findsNothing,
      reason: '닫으면 안내 바가 사라진다',
    );
    handle.dispose();
  });
}
