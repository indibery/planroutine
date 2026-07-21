import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/notifications/domain/notification_settings.dart';

void main() {
  group('직렬화 라운드트립', () {
    test('toJson → fromJson 하면 원본과 동일', () {
      const original = NotificationSettings(
        masterEnabled: true,
        monthStartEnabled: false,
        weeklyEnabled: true,
        dayOfEnabled: false,
        hour: 9,
        minute: 30,
      );
      final restored = NotificationSettings.fromJson(original.toJson());
      expect(restored, original);
    });

    test('toJson은 새 키(dayOfEnabled·weeklyEnabled)를 쓴다', () {
      const s = NotificationSettings(dayOfEnabled: false, weeklyEnabled: false);
      final json = s.toJson();
      expect(json.containsKey('dayOfEnabled'), isTrue);
      expect(json.containsKey('weeklyEnabled'), isTrue);
      expect(json.containsKey('dayBeforeEnabled'), isFalse);
      expect(json.containsKey('weekBeforeEnabled'), isFalse);
    });
  });

  group('옛 키 dayBeforeEnabled는 더 이상 읽지 않음', () {
    test('옛 키만 있으면 무시하고 기본값 true', () {
      // 이전 버전의 "1일 전" 설정은 승계하지 않는다 (기능 완전 제거)
      final restored = NotificationSettings.fromJson({
        'masterEnabled': true,
        'dayBeforeEnabled': false,
      });
      expect(restored.dayOfEnabled, isTrue);
    });

    test('새 키 dayOfEnabled를 그대로 읽는다', () {
      final restored = NotificationSettings.fromJson({
        'dayOfEnabled': false,
      });
      expect(restored.dayOfEnabled, isFalse);
    });

    test('둘 다 없으면 기본값 true', () {
      final restored = NotificationSettings.fromJson({'masterEnabled': true});
      expect(restored.dayOfEnabled, isTrue);
    });
  });

  group('옛 키 weekBeforeEnabled는 더 이상 읽지 않음', () {
    test('옛 키만 있으면 무시하고 기본값 true', () {
      // 이전 버전의 "1주 전" 설정은 승계하지 않는다 (기능 완전 제거)
      final restored = NotificationSettings.fromJson({
        'masterEnabled': true,
        'weekBeforeEnabled': false,
      });
      expect(restored.weeklyEnabled, isTrue);
    });

    test('새 키 weeklyEnabled를 그대로 읽는다', () {
      final restored = NotificationSettings.fromJson({
        'weeklyEnabled': false,
      });
      expect(restored.weeklyEnabled, isFalse);
    });

    test('둘 다 없으면 기본값 true', () {
      final restored = NotificationSettings.fromJson({'masterEnabled': true});
      expect(restored.weeklyEnabled, isTrue);
    });
  });
}
