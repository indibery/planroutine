import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/schedule/domain/entry_kind.dart';

/// 업무 / 학교일정 구분.
///
/// 업무는 내가 처리할 일 — 오늘 탭에 뜨고 체크·도장 대상이다.
/// 학교일정은 학교에서 일어나는 일 — 캘린더에만 보이고 완료 개념이 없다.
void main() {
  group('EntryKind 직렬화', () {
    test('DB 값으로 왕복한다', () {
      for (final kind in EntryKind.values) {
        expect(EntryKind.fromValue(kind.dbValue), kind);
      }
    });

    test('업무는 task, 학교일정은 event로 저장된다', () {
      expect(EntryKind.task.dbValue, 'task');
      expect(EntryKind.event.dbValue, 'event');
    });

    test('null이면 업무로 본다 (v7 이전 데이터)', () {
      // 마이그레이션 기본값이 task이므로 null은 실무상 나오지 않지만,
      // 컬럼이 없던 시절 백업을 복원하는 경로가 있어 방어한다.
      expect(EntryKind.fromValue(null), EntryKind.task);
    });

    test('모르는 값이면 업무로 폴백한다', () {
      expect(EntryKind.fromValue('hologram'), EntryKind.task);
      expect(EntryKind.fromValue(''), EntryKind.task);
    });
  });

  group('EntryKind 표시', () {
    test('두 종류 모두 화면에 쓸 짧은 라벨이 있다', () {
      for (final kind in EntryKind.values) {
        expect(kind.label, isNotEmpty);
        expect(kind.label.length, lessThanOrEqualTo(4),
            reason: '배지·pill에 들어가야 하므로 짧아야 한다');
      }
    });

    test('오늘 탭에 나타나는 것은 업무뿐이다', () {
      expect(EntryKind.task.showsInToday, isTrue);
      expect(EntryKind.event.showsInToday, isFalse);
    });
  });
}
