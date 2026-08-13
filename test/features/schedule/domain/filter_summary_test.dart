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
    int visible = 21,
  }) {
    return buildFilterSummary(
      status: status,
      kind: kind,
      categoryLabel: categoryLabel,
      visibleCount: visible,
    );
  }

  group('상태', () {
    test('대기 뷰는 대기 건수를 말한다', () {
      expect(summary(), '검토 대기 21');
    });

    test('확정됨 뷰는 확정 건수를 말한다', () {
      expect(
        summary(status: ScheduleStatus.confirmed, visible: 128),
        '확정됨 128',
      );
    });

    test('상태 필터가 없으면 전체 건수를 말한다', () {
      expect(summary(status: null, visible: 149), '전체 149');
    });
  });

  /// 요약이 말하는 숫자는 **지금 목록에 보이는 건수**다.
  /// 전역 건수를 쓰면 좁혀서 빈 화면인데 `검토 대기 21`이라고 우기게 된다.
  group('건수는 좁힌 목록을 따라간다', () {
    test('좁혀서 0건이면 0을 말한다', () {
      expect(
        summary(kind: EntryKind.event, categoryLabel: '학교행사', visible: 0),
        '검토 대기 0 · 행사 · 학교행사',
      );
    });
  });

  group('종류·카테고리를 덧붙인다', () {
    test('종류만 켜져 있으면 가운뎃점으로 잇는다', () {
      expect(summary(kind: EntryKind.task), '검토 대기 21 · 업무');
      expect(summary(kind: EntryKind.event), '검토 대기 21 · 행사');
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

  /// 일괄 확정·삭제 다이얼로그의 범위 이름. 실제 쿼리 범위와 같은 두 값에서 나온다 —
  /// 어긋나면 `전체 검토 대기 4건`이라고 묻고 21건을 지우는 일이 생긴다.
  group('범위 이름', () {
    test('아무 필터도 없으면 전체', () {
      expect(buildScopeLabel(kind: null, categoryLabel: null), '전체');
      expect(buildScopeLabel(kind: null, categoryLabel: ''), '전체');
    });

    test('종류만 걸리면 종류 이름', () {
      expect(buildScopeLabel(kind: EntryKind.event, categoryLabel: null), '행사');
    });

    test('카테고리만 걸리면 카테고리 이름', () {
      expect(buildScopeLabel(kind: null, categoryLabel: '일과운영'), '일과운영');
    });

    test('둘 다 걸리면 종류 · 카테고리', () {
      expect(
        buildScopeLabel(kind: EntryKind.task, categoryLabel: '일과운영'),
        '업무 · 일과운영',
      );
    });
  });

  group('기본값에서 벗어났는지', () {
    test('종류·카테고리가 없으면 기본 상태다', () {
      expect(hasNarrowingFilter(kind: null, categoryLabel: null), isFalse);
      expect(hasNarrowingFilter(kind: null, categoryLabel: ''), isFalse);
    });

    test('종류나 카테고리가 걸리면 좁혀진 상태다', () {
      expect(
        hasNarrowingFilter(kind: EntryKind.task, categoryLabel: null),
        isTrue,
      );
      expect(hasNarrowingFilter(kind: null, categoryLabel: '일과운영'), isTrue);
    });
  });
}
