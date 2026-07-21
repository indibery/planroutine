import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/notifications/domain/notification_settings.dart';

void main() {
  group('직렬화 라운드트립', () {
    test('toJson → fromJson 하면 원본과 동일', () {
      const original = NotificationSettings(
        masterEnabled: true,
        monthStartEnabled: false,
        weekBeforeEnabled: true,
        dayOfEnabled: false,
        hour: 9,
        minute: 30,
      );
      final restored = NotificationSettings.fromJson(original.toJson());
      expect(restored, original);
    });

    test('toJson은 새 키 dayOfEnabled를 쓴다', () {
      const s = NotificationSettings(dayOfEnabled: false);
      expect(s.toJson().containsKey('dayOfEnabled'), isTrue);
      expect(s.toJson().containsKey('dayBeforeEnabled'), isFalse);
    });
  });

  group('역호환 (옛 키 dayBeforeEnabled)', () {
    test('옛 키만 있으면 그 값을 dayOfEnabled로 읽는다 (OFF 보존)', () {
      // 이전 버전 사용자가 "1일 전"을 꺼둔 상태로 저장한 prefs
      final restored = NotificationSettings.fromJson({
        'masterEnabled': true,
        'dayBeforeEnabled': false,
      });
      expect(restored.dayOfEnabled, isFalse);
    });

    test('새 키가 있으면 옛 키보다 우선', () {
      final restored = NotificationSettings.fromJson({
        'dayOfEnabled': true,
        'dayBeforeEnabled': false,
      });
      expect(restored.dayOfEnabled, isTrue);
    });

    test('둘 다 없으면 기본값 true', () {
      final restored = NotificationSettings.fromJson({'masterEnabled': true});
      expect(restored.dayOfEnabled, isTrue);
    });
  });
}
