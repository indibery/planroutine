import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/utils/date_utils.dart' as du;
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
      // ⚠️ **`같은 항목이`로 조건을 좁혀 둔다.** `같은 날짜의 여러 항목`이라고만
      // 쓰면 서로 다른 할 일까지 삼킨다 — 손글씨 목록 세 줄 중 `오늘`짜리 둘이
      // 그렇게 사라졌다(실측 2026-08-07, 세 모델 모두 1건만 반환).
      expect(p, contains('**같은 항목이** 같은 날짜로'));
    });

    test('목록 사진은 빠짐없이 한 줄에 한 건으로 뽑으라고 말한다', () {
      // 이 프롬프트는 원래 **문서에서 마감일 찾기**용이었다. 손글씨 할 일 목록을
      // 넣었더니 필터가 그대로 걸려 세 줄 중 하나만 남았다(실측 2026-08-07).
      // 목록과 문서는 요구가 정반대다 — 문서는 대부분 버려야 하고 목록은 전부
      // 남겨야 한다. 그래서 가지를 갈랐다.
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, contains('하나도 빠짐없이, 한 줄에 한 건씩'));
      expect(p, contains('서로 다른 할 일은 날짜가 같아도 따로 둡니다'));
      // 목록에서만 오늘로 떨어진다 — 문서에서 없는 날짜를 지어내면 안 된다.
      expect(p, contains('날짜가 안 적힌 줄은 오늘 날짜로'));
      expect(p, contains('날짜를 알 수 없어도 건너뜁니다'));
    });

    test('프롬프트 안의 모든 날짜는 주입값이다 — 고정 예시를 박지 않는다', () {
      // **이 가드가 없어서 놓친 버그가 있다.** 예전 프롬프트는 규칙은 상대적인데
      // (`오늘 이후 가장 가까운`) 예시는 고정이었다:
      //
      //   오늘은 2027-01-15입니다.
      //   ... `1월 20일`은 내년 1월 20일입니다.   ← 2028-01-20으로 읽힌다
      //
      // 맞는 답은 닷새 뒤인 2027-01-20이다. 기존 테스트는 `오늘은 …입니다`가
      // 들어가는지와 `2026`이 없는지만 봤을 뿐, **예시가 규칙과 모순되는지는
      // 아무도 보지 않았다**(사용자 지적 2026-08-07).
      //
      // 그래서 형태로 막는다: 프롬프트에 나오는 `yyyy-MM-dd`는 전부 주입된
      // 값(오늘·내일·사흘 전)이어야 한다. 손으로 박은 날짜가 생기면 걸린다.
      for (final today in [
        DateTime(2027, 1, 15), // 연초 — 옛 예시가 틀리던 지점
        DateTime(2026, 8, 7),
        DateTime(2026, 12, 28), // 연말 — 사흘 전 예시가 해를 넘는다
      ]) {
        final p = buildAiPhotoPrompt(today, kind: EntryKind.task);
        final allowed = {
          du.formatDate(today),
          du.formatDate(today.add(const Duration(days: 1))),
          du.formatDate(today.subtract(const Duration(days: 3))),
        };
        final found = RegExp(r'\d{4}-\d{2}-\d{2}')
            .allMatches(p)
            .map((m) => m.group(0)!)
            .toSet();

        expect(found.difference(allowed), isEmpty,
            reason: '$today 기준 프롬프트에 주입값이 아닌 날짜가 있다: '
                '${found.difference(allowed)}');
        // 연도만 따로 박는 것도 막는다(`2027년 1월` 같은 형태).
        final bareYears = RegExp(r'(?<!\d)(20\d\d)(?!-)')
            .allMatches(p)
            .map((m) => m.group(1)!)
            .toSet();
        expect(bareYears, isEmpty,
            reason: '$today 기준 프롬프트에 맨 연도가 박혀 있다: $bareYears');
      }
    });

    test('최근 지난 날짜는 1년 뒤로 밀지 않는다', () {
      // 오늘이 8월 7일인데 메모에 `8월 5일`이라 적으면 `오늘 이후 가장 가까운`
      // 규칙만으로는 **2027년 8월 5일**(1년 뒤)이 된다. 이틀 전 못 한 일인데.
      // 이 앱은 오늘 탭에 `기한이 지난` 구역을 따로 두므로 지난 날짜는 그리로 간다.
      final p = buildAiPhotoPrompt(DateTime(2026, 8, 7), kind: EntryKind.task);

      expect(p, contains('최근 30일 안에 지난 날짜'));
      expect(p, contains('1년 뒤로 밀지 않습니다'));
      // 예시도 주입값이다 — 사흘 전.
      expect(p, contains('2026-08-04'));
    });

    test('상대 날짜를 실제 날짜로 바꾸라고 말한다', () {
      // `오늘`·`내일`은 문서 어휘가 아니라 메모 어휘다. 규칙에 없던 시절
      // `(오늘)`이 적힌 두 줄이 통째로 빠졌다.
      final p = buildAiPhotoPrompt(DateTime(2026, 8, 7), kind: EntryKind.task);

      expect(p, contains('`오늘`은 2026-08-07, `내일`은 2026-08-08'),
          reason: '내일 날짜도 실제 값이어야 한다 — 주입값을 따라간다');
    });

    test('날짜 말을 title에서 빼라고 말한다', () {
      // `콩나물 무침 만들기 (오늘)`이 제목으로 들어오면 **내일 보면 틀린 말**이
      // 된다(실측: Grok이 그렇게 냈다). 제목 속 연도를 미는 기능을 따로 둔 것과
      // 같은 계열의 함정이다.
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, contains('날짜를 가리키는 말은 title에서 뺍니다'));
      // 그렇다고 제목을 요약하라는 뜻은 아니다 — 줄여 쓰면 `앱 개발 서적 한권
      // 읽기`가 `앱 개발 서적 읽기`가 된다(실측).
      expect(p, contains('그대로** 씁니다'));
    });

    test('date를 반드시 채우라고 말한다 — 파서가 빈 date를 버린다', () {
      // `parseAiScheduleJson`은 `date`가 문자열이 아니면 invalid로 센다. 그리고
      // 그 건수는 **아무도 읽지 않아** 화면에 안 나온다 — 항목이 소리 없이 사라진다.
      final p = buildAiPhotoPrompt(now, kind: EntryKind.task);

      expect(p, contains('date는 반드시 채웁니다'));
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

    test('일정표에 적힌 학년도를 기본값보다 먼저 본다', () {
      // **2월에 3월 일정표를 넣으면 1년 전으로 갔다.**
      //
      // 규칙은 "문서의 학년도 = 오늘의 학년도"를 가정하는데, 2월은 아직 지난
      // 학년도라 `schoolYear`가 전년이 된다. 그 상태로 `3~12월은 전년`이 걸리면
      // 새 학년도 3월 행사가 통째로 1년 전으로 들어간다 — 캘린더에도 오늘 탭에도
      // 안 보인다. 3월은 입학식·시업식이 몰린 달이라 손실이 크다.
      //
      // 한 달 전에 다음 달 행사를 넣는 실사용 패턴을 12개월로 계산해 보면
      // **2월 한 곳만** 어긋난다(사용자와 확인, 2026-08-08). 그런데 그 2월은
      // 매년 반드시 온다.
      //
      // 오늘 날짜만으로는 못 고친다 — 2월에 2월 일정표를 넣는 사람과 3월
      // 일정표를 넣는 사람이 같은 프롬프트를 받는데 정답이 다르다. 그래서
      // **문서가 스스로 말하게** 한다.
      final p = buildAiPhotoPrompt(DateTime(2027, 2, 10), kind: EntryKind.event);

      expect(p, contains('학년도나 연도가 적혀 있으면 그것을 따릅니다'));
      expect(p, contains('적혀 있지 않을 때만'),
          reason: '기본값은 폴백이라는 것이 문장에 드러나야 한다');

      // 예시는 **계산해서** 넣는다 — 고정 연도를 박으면 규칙과 모순된다
      // (업무 프롬프트에서 정확히 그 사고가 있었다).
      expect(p, contains('2027학년도'),
          reason: '2027-02 기준 다음 학년도가 2027이므로 그 값이 예시가 된다');
      expect(p, contains('3~12월은 2027년'));
    });

    test('행사 프롬프트의 학년도 예시도 주입값이다', () {
      // 고정 문자열이면 해가 바뀌는 순간 규칙과 어긋난다.
      for (final today in [DateTime(2029, 5, 1), DateTime(2030, 1, 15)]) {
        final p = buildAiPhotoPrompt(today, kind: EntryKind.event);
        final school = today.month >= 3 ? today.year : today.year - 1;

        expect(p, contains('${school + 1}학년도'),
            reason: '$today 기준 예시 학년도가 주입값을 따라가지 않는다');
        expect(p, isNot(contains('2026')),
            reason: '$today 기준 프롬프트에 옛 연도가 남아 있다');
      }
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
