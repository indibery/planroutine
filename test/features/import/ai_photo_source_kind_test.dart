import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/import/data/ai_schedule_parser.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

void main() {
  final now = DateTime(2026, 10, 1);

  group('사진 AI 프롬프트 — 소스 문서로 갈린다', () {
    test('행사는 일정표를 읽는 지시다', () {
      final p = buildAiPhotoPrompt(now, kind: EntryKind.event);

      expect(p, contains('월간·연간 일정표'));
      expect(p, contains('표에 있는 모든 일정'));
      // 기간은 **시작일** 기준 — 행사는 시작하는 날이 중요하다.
      expect(p, contains('시작일 기준'));
    });

    test('업무는 쪽지에서 기한을 찾는 지시다', () {
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, contains('쪽지'));
      expect(p, contains('마감'));
      expect(p, contains('기한'));
      // 기간은 **마지막 날** 기준 — 마감은 끝나는 날이 중요하다. 행사와 반대다.
      expect(p, contains('마지막 날'));
    });

    test('두 프롬프트가 기간 규칙을 서로 반대로 말한다', () {
      // 이 차이가 프롬프트를 갈라 쓰는 이유다. 한 프롬프트로 둘을 다 지시하면
      // AI가 어느 쪽을 쓸지 모른다.
      final event = buildAiPhotoPrompt(now, kind: EntryKind.event);
      final task = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(event.contains('시작일 기준'), isTrue);
      expect(event.contains('마지막 날'), isFalse);
      expect(task.contains('마지막 날'), isTrue);
      expect(task.contains('시작일 기준'), isFalse);
    });

    test('기본값은 행사다 — 기존 호출부의 동작이 바뀌지 않는다', () {
      expect(
        buildAiPhotoPrompt(now),
        buildAiPhotoPrompt(now, kind: EntryKind.event),
      );
    });

    test('연도 규칙은 두 프롬프트가 공유한다 — 학년도 기준', () {
      // 10월이면 그 해가 학년도다. 한쪽만 고치면 쪽지의 날짜가 1년 틀어진다.
      for (final kind in EntryKind.values) {
        final p = buildAiPhotoPrompt(now, kind: kind);
        expect(p, contains('3~12월은 2026년'));
        expect(p, contains('1~2월은 2027년'));
      }
    });

    test('1~2월에 찍으면 학년도가 전년이다', () {
      final p = buildAiPhotoPrompt(DateTime(2027, 2, 10), kind: EntryKind.task);

      expect(p, contains('3~12월은 2026년'));
      expect(p, contains('1~2월은 2027년'));
    });

    test('업무 프롬프트는 기한 없는 행사를 걸러내라고 말한다', () {
      // 쪽지에 운동회 안내만 있고 내가 할 일이 없으면 아무것도 뽑지 않아야 한다 —
      // 안 그러면 오늘 탭에 완료할 수 없는 항목이 쌓인다.
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, contains('건너뜁니다'));
      expect(p, contains('빈 배열'));
    });
  });
}
