import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/filter_summary.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';

/// 접힌 필터 줄에 들어가는 요약 문자열.
///
/// 필터를 접어도 **무엇으로 걸러진 상태인지**는 화면에 남아야 한다.
/// 이게 3안의 전제다 — 안 보이면 5안(상단 아이콘)과 같은 약점을 갖는다.
void main() {
  String summary({
    ScheduleStatus? status = ScheduleStatus.pending,
    EntryKind? kind,
    String? categoryLabel,
    int pending = 21,
    int confirmed = 128,
  }) {
    return buildFilterSummary(
      status: status,
      kind: kind,
      categoryLabel: categoryLabel,
      pendingCount: pending,
      confirmedCount: confirmed,
    );
  }

  group('상태', () {
    test('대기 뷰는 대기 건수를 말한다', () {
      expect(summary(), '검토 대기 21');
    });

    test('확정됨 뷰는 확정 건수를 말한다', () {
      expect(summary(status: ScheduleStatus.confirmed), '확정됨 128');
    });

    test('상태 필터가 없으면 전체 건수를 말한다', () {
      expect(summary(status: null), '전체 149');
    });
  });

  group('종류·카테고리를 덧붙인다', () {
    test('종류만 켜져 있으면 가운뎃점으로 잇는다', () {
      expect(summary(kind: EntryKind.task), '검토 대기 21 · 업무');
      expect(summary(kind: EntryKind.event), '검토 대기 21 · 학교일정');
    });

    test('카테고리만 켜져 있어도 잇는다', () {
      expect(summary(categoryLabel: '일과운영'), '검토 대기 21 · 일과운영');
    });

    test('셋 다 켜지면 상태 · 종류 · 카테고리 순', () {
      expect(
        summary(kind: EntryKind.task, categoryLabel: '일과운영'),
        '검토 대기 21 · 업무 · 일과운영',
      );
    });

    test('빈 카테고리 문자열은 붙이지 않는다', () {
      expect(summary(categoryLabel: ''), '검토 대기 21');
    });
  });

  group('기본값에서 벗어났는지', () {
    test('종류·카테고리가 없으면 기본 상태다', () {
      expect(hasNarrowingFilter(kind: null, categoryLabel: null), isFalse);
      expect(hasNarrowingFilter(kind: null, categoryLabel: ''), isFalse);
    });

    test('종류나 카테고리가 걸리면 좁혀진 상태다', () {
      expect(hasNarrowingFilter(kind: EntryKind.task, categoryLabel: null),
          isTrue);
      expect(hasNarrowingFilter(kind: null, categoryLabel: '일과운영'), isTrue);
    });
  });
}
