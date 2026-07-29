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

    test('업무는 날짜 있는 할 일을 찾는 지시다', () {
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, contains('내가 해야 할 일'));
      expect(p, contains('기억해야 할 날'));
      // 기간은 **마지막 날** 기준 — 마감은 끝나는 날이 중요하다. 행사와 반대다.
      expect(p, contains('마지막 날'));
    });

    test('학교에 묶이지 않는다 — 소스를 좁히면 그 밖의 사진이 걸러진다', () {
      // 실사용 예: 도서관 대출 화면의 `반납예정일`(사용자 사진 2026-07-29).
      // 학교 문서라고 못박으면 AI가 "대상이 아니다"로 판단할 수 있다.
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, isNot(contains('학교에서 받은')));
      expect(p, contains('무엇이든 될 수 있습니다'));
    });

    test('학교 밖 기한 낱말들을 예시로 준다', () {
      // 낱말을 열거하지 않으면 `반납예정일`·`납부기한`처럼 `마감`이라는 말이 없는
      // 표현을 AI가 놓친다 — 도서관 화면이 정확히 그 경우였다.
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      for (final word in ['반납예정일', '납부기한', '유효기간', '예약일']) {
        expect(p, contains(word), reason: '$word이 예시에 없다');
      }
    });

    test('같은 날짜 여러 항목은 한 건으로 묶으라고 말한다', () {
      // 도서관 화면은 책 2권이 같은 반납일이었다. 2건으로 넣으면 오늘 탭에 같은
      // 일이 두 줄로 뜬다.
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, contains('한 건으로 묶고'));
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

    test('행사는 학년도 규칙을 쓴다', () {
      // 학사일정은 3월에 시작해 다음 2월에 끝나는 한 덩어리다.
      final p = buildAiPhotoPrompt(now, kind: EntryKind.event);

      expect(p, contains('3~12월은 2026년'));
      expect(p, contains('1~2월은 2027년'));
      expect(p, contains('학년도 기준'));
    });

    test('1~2월에 찍으면 행사의 학년도는 전년이다', () {
      final p = buildAiPhotoPrompt(DateTime(2027, 2, 10), kind: EntryKind.event);

      expect(p, contains('3~12월은 2026년'));
      expect(p, contains('1~2월은 2027년'));
    });

    test('업무는 학년도를 쓰지 않는다 — 오늘 기준 가장 가까운 미래다', () {
      // 학년도를 쓰면 마감이 어긋난다(사용자 지적 2026-07-29):
      //  · 2027-05에 찍은 `1월 20일` → 학년도로는 2028-01-20 (8개월 뒤)
      //  · 2027-01에 찍은 `12월 3일` → 학년도로는 2026-12-03 (이미 지난 날)
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, isNot(contains('학년도')));
      expect(p, contains('오늘은 2026-10-01입니다'));
      expect(p, contains('오늘 이후 가장 가까운'));
    });

    test('업무 프롬프트의 오늘 날짜는 인자를 따라간다', () {
      // 고정 문구가 아니라 주입값이다 — 안 따라가면 모든 상대 날짜가 틀어진다.
      final p = buildAiPhotoPrompt(DateTime(2027, 1, 15), kind: EntryKind.task);

      expect(p, contains('오늘은 2027-01-15입니다'));
      expect(p, isNot(contains('2026')));
    });

    test('두 프롬프트의 연도 규칙이 서로 다르다', () {
      final event = buildAiPhotoPrompt(now, kind: EntryKind.event);
      final task = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(event.contains('학년도 기준'), isTrue);
      expect(task.contains('학년도 기준'), isFalse);
      expect(task.contains('오늘 이후 가장 가까운'), isTrue);
      expect(event.contains('오늘 이후 가장 가까운'), isFalse);
    });

    test('업무는 자세한 내용을 description에 넣으라고 말한다', () {
      // 도서관 사진에서 책 제목이 어디에도 안 남으면 `도서 2권 반납`만 보고
      // 어느 책인지 알 수 없다(사용자 요청 2026-07-29).
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, contains('자세한 내용'));
      expect(p, contains('책 제목'));
    });

    test('업무 프롬프트는 내 일이 아닌 것을 걸러내라고 말한다', () {
      // 안내만 있고 내가 할 일이 없으면 아무것도 뽑지 않아야 한다 — 안 그러면
      // 오늘 탭에 완료할 수 없는 항목이 쌓인다. 남이 하는 일·끝난 일도 같다.
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, contains('건너뜁니다'));
      expect(p, contains('빈 배열'));
      expect(p, contains('남이 하는 일'));
    });
  });
}
