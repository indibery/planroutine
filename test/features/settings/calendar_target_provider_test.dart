import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/settings/presentation/providers/calendar_target_provider.dart';

void main() {
  group('CalendarTarget 직렬화', () {
    test('알려진 enum 값 round-trip', () {
      for (final t in CalendarTarget.values) {
        expect(CalendarTarget.fromValue(t.prefValue), t);
      }
    });

    test('null 또는 unknown 값은 none', () {
      expect(CalendarTarget.fromValue(null), CalendarTarget.none);
      expect(CalendarTarget.fromValue(''), CalendarTarget.none);
      expect(CalendarTarget.fromValue('outlook'), CalendarTarget.none);
    });

    test('prefValue는 enum name과 동일', () {
      expect(CalendarTarget.none.prefValue, 'none');
      expect(CalendarTarget.google.prefValue, 'google');
      expect(CalendarTarget.device.prefValue, 'device');
    });
  });
}
