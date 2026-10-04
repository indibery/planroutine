// 디자인 통일 점검(2026-10-04)의 결정이 화면에서 지켜지는지 소스로 본다.
//
// 결정은 사용자가 캔버스 시안에서 골랐다(모두 A안). 화면을 새로 만들 때 옛 모양을 복사해
// 오면 여기서 걸린다 — 실제로 탭 머리는 네 화면이 같은 코드를 복사해 두고 두 화면만 빠져 있었다.

import 'package:flutter_test/flutter_test.dart';

import '../helpers/source_scan.dart';

String _code(String path) => strippedCode(path);

const _tabScreens = [
  'lib/features/today/presentation/screens/today_screen.dart',
  'lib/features/calendar/presentation/screens/calendar_screen.dart',
  'lib/features/schedule/presentation/screens/schedule_screen.dart',
  'lib/features/settings/presentation/screens/settings_screen.dart',
  'lib/features/memo/presentation/screens/memo_board_screen.dart',
  'lib/features/guidance/presentation/screens/guidance_list_screen.dart',
];

const _emptyStateScreens = [
  'lib/features/schedule/presentation/screens/schedule_screen.dart',
  'lib/features/trash/presentation/screens/trash_screen.dart',
  'lib/features/memo/presentation/screens/memo_board_screen.dart',
  'lib/features/guidance/presentation/screens/guidance_list_screen.dart',
  'lib/features/guidance/presentation/screens/guidance_trash_screen.dart',
];

/// [open] 바로 뒤(여는 괄호 다음)부터 짝이 맞는 닫는 괄호까지 — 한 호출의 인자 전체.
String _callArgs(String code, int open) {
  var depth = 1;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return code.substring(open, i);
  }
  return code.substring(open);
}

void main() {
  test('모든 탭 화면이 TabHeaderTitle로 eyebrow + 제목을 그린다', () {
    for (final path in _tabScreens) {
      final code = _code(path);
      expect(code, contains('TabHeaderTitle('), reason: path);
      expect(
        code,
        isNot(contains('AppTextStyles.eyebrow')),
        reason: '$path — 탭 머리를 직접 조립하지 않는다',
      );
    }
  });

  test('목록이 비는 화면은 EmptyState를 쓴다', () {
    for (final path in _emptyStateScreens) {
      expect(_code(path), contains('EmptyState('), reason: path);
    }
  });

  test('세그먼트는 모두 선택 체크 아이콘을 끈다', () {
    final segment = RegExp(r'\bSegmentedButton<[^>]+>\(');
    final offenders = <String>[];
    for (final f in libDartFiles()) {
      final code = _code(f.path);
      for (final m in segment.allMatches(code)) {
        if (!_callArgs(code, m.end).contains('showSelectedIcon: false')) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('지도 기록 목록은 다른 탭과 같은 추가 버튼·선택 칩을 쓴다', () {
    final code = _code(
      'lib/features/guidance/presentation/screens/guidance_list_screen.dart',
    );
    expect(code, contains('GoldFab('));
    expect(code, isNot(contains('FloatingActionButton(')));
    expect(code, contains('PillChip('));
    expect(code, isNot(contains('ChoiceChip(')));
  });

  test('날짜·시각 칸은 PickerFieldTile 하나로 그린다', () {
    for (final path in [
      'lib/features/calendar/presentation/widgets/event_edit_dialog.dart',
      'lib/features/guidance/presentation/widgets/occurred_input.dart',
      'lib/features/schedule/presentation/widgets/schedule_edit_sheet.dart',
    ]) {
      expect(_code(path), contains('PickerFieldTile('), reason: path);
    }
    // 지도 기록의 사건 시각은 골드 테두리 알약 버튼이었다.
    expect(
      _code('lib/features/guidance/presentation/widgets/occurred_input.dart'),
      isNot(contains('OutlinedButton')),
    );
  });

  test('제목이 있는 시트는 SheetTitle로 가운데 제목을 그린다', () {
    for (final path in [
      'lib/features/schedule/presentation/widgets/schedule_edit_sheet.dart',
      'lib/features/settings/presentation/widgets/stamp_style_sheet.dart',
      'lib/features/bus/presentation/widgets/bus_stop_confirm_sheet.dart',
      'lib/features/guidance/presentation/widgets/attachment_info_sheet.dart',
      'lib/features/guidance/presentation/screens/guidance_list_screen.dart',
    ]) {
      expect(_code(path), contains('SheetTitle('), reason: path);
    }
  });
}
