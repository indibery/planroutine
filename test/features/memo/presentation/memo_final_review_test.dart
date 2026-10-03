// 최종 리뷰가 잡은 넷 — 저장 버튼 대비 · 큰 글자 쪽지 카드 · 날짜 상한 · 휴지통 설명.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/features/memo/domain/memo.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_card.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_sheet.dart';

import '../../../helpers/contrast.dart';

const _memo = Memo(
  id: 1,
  text: '운동회 물품',
  memoDate: null,
  createdAt: '2026-10-03T09:00:00',
);

Future<void> _pumpSheet(WidgetTester tester, Brightness b, Memo memo) async {
  AppColors.applyBrightness(b);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.of(b),
        home: Scaffold(body: MemoSheet(memo: memo)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  // Material의 채움 버튼은 `primary`를 칠한다. 라이트의 primary(`gold`)는 배경 위 글자용
  // 딥골드라 네이비 글자와 3.57:1이 된다(CLAUDE.md "primary를 채움으로 주면 안 된다").
  // 토큰이 아니라 **렌더된** 바탕과 글자를 잰다.
  for (final b in Brightness.values) {
    final name = b == Brightness.light ? '라이트' : '다크';
    testWidgets('$name — 저장 버튼 글자가 바탕과 AA(4.5:1)', (tester) async {
      await _pumpSheet(tester, b, _memo);
      final button = find.byKey(MemoSheet.saveKey);
      final bg = tester
          .widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)).first,
          )
          .color;
      final fg = tester
          .widget<RichText>(
            find.descendant(of: button, matching: find.byType(RichText)),
          )
          .text
          .style
          ?.color;
      expect(bg, isNotNull);
      expect(fg, isNotNull);
      final ratio = contrastRatio(
        fg ?? Colors.transparent,
        bg ?? Colors.transparent,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '$name 저장 버튼 ${ratio.toStringAsFixed(2)}:1',
      );
    });
  }

  // iOS 글자 크기를 키운 사용자. 보드 칸은 높이가 고정이라 5줄 글 + 날짜가 칸을 넘으면 안 된다.
  testWidgets('글자 1.3배에서도 5줄 쪽지 카드가 칸을 넘치지 않는다', (tester) async {
    AppColors.applyBrightness(Brightness.light);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Center(
            child: SizedBox(
              width: 170,
              height: 168,
              child: MemoCard(
                memo: _memo.copyWith(
                  text: List.filled(12, '줄이 길게 이어지는 메모 글입니다').join(' '),
                  memoDate: DateTime(2026, 10, 17),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // 쪽지 날짜로 만든 일정은 일정 편집 시트에서 다시 열린다. 그 시트의 상한(2030)보다 뒤의
  // 날짜를 고를 수 있으면, 그 일정의 날짜를 누를 때 initialDate > lastDate가 된다.
  testWidgets('날짜 선택 상한이 일정 편집 시트와 같다(2030)', (tester) async {
    await _pumpSheet(
      tester,
      Brightness.light,
      _memo.copyWith(memoDate: DateTime(2026, 10, 17)),
    );
    await tester.tap(find.byKey(MemoSheet.dateRowKey));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.lastDate, DateTime(2030));
  });

  test('설정 탭의 휴지통 설명이 포스트잇을 말한다', () {
    expect(SettingsStrings.trashDescription, contains('포스트잇'));
  });
}
