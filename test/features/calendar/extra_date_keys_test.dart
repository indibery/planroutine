import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/domain/extra_date_keys.dart';

void main() {
  test('없는 날짜 키를 빈 목록으로 더하고 날짜순으로 둔다', () {
    final out = mergeExtraDateKeys<int>(
      [const MapEntry('2026-10-05', [1]), const MapEntry('2026-10-20', [2])],
      ['2026-10-17', '2026-10-05'],
    );
    expect(out.map((e) => e.key), ['2026-10-05', '2026-10-17', '2026-10-20']);
    expect(out[0].value, [1], reason: '있는 키는 그대로');
    expect(out[1].value, isEmpty);
  });
}
