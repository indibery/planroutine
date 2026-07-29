import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/today/domain/stamp_settings.dart';

void main() {
  group('StampSettings 기본값', () {
    test('기본 도장은 완료이고, 이미 찍은 도장 흐리게는 켜져 있다', () {
      const settings = StampSettings.defaults;

      expect(settings.style, SealStyle.complete);
      expect(settings.dimPreviousStamps, isTrue);
    });
  });

  group('StampSettings 직렬화', () {
    test('저장한 값이 그대로 복원된다', () {
      const settings = StampSettings(
        style: SealStyle.approve,
        dimPreviousStamps: false,
      );

      final restored = StampSettings.fromJson(settings.toJson());

      expect(restored.style, SealStyle.approve);
      expect(restored.dimPreviousStamps, isFalse);
    });

    test('세 가지 도장 모양 모두 왕복한다', () {
      for (final style in SealStyle.values) {
        final restored = StampSettings.fromJson(
          StampSettings(style: style).toJson(),
        );
        expect(restored.style, style);
      }
    });

    test('빈 JSON이면 기본값으로 복원된다', () {
      final restored = StampSettings.fromJson(const {});

      expect(restored.style, SealStyle.complete);
      expect(restored.dimPreviousStamps, isTrue);
    });

    test('모르는 도장 이름이 저장돼 있으면 완료로 폴백한다', () {
      final restored = StampSettings.fromJson(const {'style': 'hologram'});

      expect(restored.style, SealStyle.complete);
    });
  });

  group('SealStyle', () {
    test('모든 모양에 설정 화면에 쓸 라벨이 있다', () {
      for (final style in SealStyle.values) {
        expect(style.label, isNotEmpty);
      }
    });

    test('모양마다 그리는 것이 다르다', () {
      expect(SealStyle.complete.mark, SealMark.text);
      expect(SealStyle.approve.mark, SealMark.text);
      expect(SealStyle.panda.mark, SealMark.panda);
    });

    test('판다는 사각이 아니다 — 결재만 사각이다', () {
      expect(SealStyle.panda.isSquare, isFalse);
    });

    test('판다도 직렬화 왕복한다', () {
      const s = StampSettings(style: SealStyle.panda);
      expect(StampSettings.fromJson(s.toJson()).style, SealStyle.panda);
    });

    test('없어진 좋아요 도장을 고른 사용자는 기본 도장으로 돌아간다', () {
      // `좋아요`를 빼면서 그 값은 저장값(`shared_preferences`)에 `"like"`로 남는다.
      // 없어진 모양을 되살릴 방법이 없으므로 기본값 폴백이 맞고, **조용한 변경**이라
      // 여기서 고정한다. 이 폴백이 깨지면 앱이 켜질 때 도장 설정이 사라진다.
      final s = StampSettings.fromJson(const {
        'style': 'like',
        'dimPreviousStamps': false,
      });

      expect(s.style, SealStyle.complete);
      // 모양만 폴백하고 **다른 설정은 유지**한다.
      expect(s.dimPreviousStamps, isFalse);
    });

    test('결재만 사각 도장이다', () {
      expect(SealStyle.approve.isSquare, isTrue);
      expect(SealStyle.complete.isSquare, isFalse);
      expect(SealStyle.panda.isSquare, isFalse);
    });
  });
}
