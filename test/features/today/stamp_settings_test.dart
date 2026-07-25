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

    test('완료·결재는 글자 도장, 좋아요는 아이콘 도장이다', () {
      expect(SealStyle.complete.usesIcon, isFalse);
      expect(SealStyle.approve.usesIcon, isFalse);
      expect(SealStyle.like.usesIcon, isTrue);
    });

    test('결재만 사각 도장이다', () {
      expect(SealStyle.approve.isSquare, isTrue);
      expect(SealStyle.complete.isSquare, isFalse);
      expect(SealStyle.like.isSquare, isFalse);
    });
  });
}
