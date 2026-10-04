// 디자인 통일 점검(2026-10-04)에서 화면마다 따로 그리던 것을 공통 위젯으로 모았다.
//
// - `TabHeaderTitle`: 탭 머리(영문 eyebrow + 제목). 오늘·입력·포스트잇·지도 기록은 같은 코드를
//   복사해 두고, 캘린더·설정에는 eyebrow가 없었다(사용자 결정 A: 모든 탭에 둔다).
// - `EmptyState`: 빈 상태(아이콘 + 제목 + 다음 행동 한 줄). 아이콘 64·48·없음, 글자 15·14·12가
//   화면마다 달랐다(사용자 결정 A: 모두 아이콘 + 두 줄).
// - `PickerFieldTile`: 날짜·시각 칸. 일정 시트는 테두리 타일, 지도 기록은 골드 테두리 알약
//   버튼이었다(일정 시트 모양으로 맞춤).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/theme/app_text_styles.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/shared/widgets/empty_state.dart';
import 'package:planroutine/shared/widgets/picker_field_tile.dart';
import 'package:planroutine/shared/widgets/sheet_title.dart';
import 'package:planroutine/shared/widgets/tab_header_title.dart';

import '../helpers/text_glyph.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  AppColors.applyBrightness(Brightness.light);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.of(Brightness.light),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  testWidgets('탭 머리는 eyebrow 위에 제목을 가운데로 쌓는다', (tester) async {
    await _pump(
      tester,
      const TabHeaderTitle(eyebrow: 'CALENDAR', title: '캘린더'),
    );
    expect(
      textStyleOf(tester, find.text('CALENDAR'))?.letterSpacing,
      AppTextStyles.eyebrow.letterSpacing,
    );
    expect(textStyleOf(tester, find.text('캘린더'))?.fontSize, AppTextStyles.heading.fontSize);
    expect(
      tester.getCenter(find.text('CALENDAR')).dy <
          tester.getCenter(find.text('캘린더')).dy,
      isTrue,
    );
    expect(
      tester.getCenter(find.text('CALENDAR')).dx,
      moreOrLessEquals(tester.getCenter(find.text('캘린더')).dx, epsilon: 0.5),
    );
  });

  testWidgets('탭 머리의 영문 eyebrow는 스크린리더가 읽지 않는다', (tester) async {
    // 장식용 소제목이다. 캘린더·설정에도 붙으면서 "CALENDAR 캘린더"처럼 영문까지 읽혔다
    // (verifier가 짚었다, 2026-10-04).
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const TabHeaderTitle(eyebrow: 'CALENDAR', title: '캘린더'),
    );
    expect(find.bySemanticsLabel('CALENDAR'), findsNothing);
    expect(find.bySemanticsLabel('캘린더'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('빈 상태는 아이콘 + 제목 15 + 다음 행동 14를 가운데 정렬로 그린다', (tester) async {
    await _pump(
      tester,
      const EmptyState(
        icon: Icons.sticky_note_2_outlined,
        title: '붙여 둔 포스트잇이 없습니다',
        hint: '위 칸에 적고 + 를 누르면 쪽지가 붙어요',
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.sticky_note_2_outlined));
    expect(icon.size, EmptyState.iconSize);
    expect(icon.color, AppColors.faint);
    expect(textStyleOf(tester, find.text('붙여 둔 포스트잇이 없습니다'))?.fontSize, 15);
    expect(textStyleOf(tester, find.text('위 칸에 적고 + 를 누르면 쪽지가 붙어요'))?.fontSize, 14);
  });

  testWidgets('빈 상태의 다음 행동 줄은 생략할 수 있다', (tester) async {
    await _pump(
      tester,
      const EmptyState(icon: Icons.delete_outline, title: '삭제한 기록이 없습니다'),
    );
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('날짜 칸은 라벨·값·아이콘을 한 줄 테두리 타일로 그리고 누르면 부른다', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      PickerFieldTile(
        label: '날짜',
        value: '2026년 10월 4일',
        icon: Icons.calendar_today,
        onTap: () => taps++,
      ),
    );
    expect(find.byType(OutlinedButton), findsNothing);
    expect(
      tester.getCenter(find.text('날짜')).dy,
      moreOrLessEquals(
        tester.getCenter(find.text('2026년 10월 4일')).dy,
        epsilon: 0.5,
      ),
    );
    expect(textStyleOf(tester, find.text('날짜'))?.fontSize, 14);
    await tester.tap(find.text('2026년 10월 4일'));
    expect(taps, 1);
  });

  testWidgets('날짜 칸은 라벨과 값을 담은 이름 있는 버튼이다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      PickerFieldTile(
        label: '시각',
        value: '14:41',
        icon: Icons.schedule,
        onTap: () {},
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('시각, 14:41')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('시트 제목은 왼쪽 정렬 칸 안에서도 가운데에 heading 글자로 선다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(Brightness.light),
        home: const Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SheetTitle('도장 모양')],
          ),
        ),
      ),
    );
    final screen = tester.getSize(find.byType(Scaffold));
    expect(
      glyphCenterX(tester, find.text('도장 모양')),
      moreOrLessEquals(screen.width / 2, epsilon: 1),
    );
    expect(
      textStyleOf(tester, find.text('도장 모양'))?.fontSize,
      AppTextStyles.heading.fontSize,
    );
  });
}
