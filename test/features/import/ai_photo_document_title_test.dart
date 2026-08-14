// 문서 사진(문자 안내문) — **실측 응답**이 파서를 통과하고, 제목이 문장이 아니다.
//
// 이 프롬프트의 (나) 갈래는 공문·안내문을 읽는다. 그런데 `title은 그대로 씁니다`가
// **공통 규칙**에 있던 동안, 본문이 경어체인 문서에서는 서술이 통째로 제목이 됐다:
//
//   실측 2026-08-14 (경기도교육청 발대식 안내 문자)
//   전: {"title": "설문에 참여하여 주시기 바랍니다", ...}   ← 오늘 탭에 뜨면 안 읽힌다
//   후: {"title": "경기도교육청 교권보호전담관 발대식 참석 설문 참여", ...}
//
// 그래서 `그대로`를 (가) 손글씨 목록으로 내리고, (나)에는 **할 일 이름으로 짧게 +
// 사진에 없는 말은 지어내지 않기**를 따로 달았다.
//
// ⚠️ **이 테스트는 모델을 다시 돌리지 않는다.** 아래는 저장된 응답이라, 프롬프트가
// 퇴행해도 여기서는 안 잡힌다 — 그 몫은 `ai_photo_source_kind_test.dart`의 절 검사다.
// 여기가 지키는 것은 ① 실측 응답이 파서를 통과한다 ② 우리가 고친 실패 서명(경어체
// 서술이 제목에 남는 것)이 이 응답에는 없다, 둘이다.

import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/import/data/ai_schedule_parser.dart';

/// 사용자가 받은 응답 원본 그대로 — 스마트 따옴표까지 손대지 않는다(리포 규칙).
const _response =
    '[{“title”:“경기도교육청 교권보호전담관 발대식 참석 설문 참여”,“date”:“2026-08-14”,'
    '“description”:“8.14.(금) 12:00까지 설문 참여”},'
    '{“title”:“경기도교육청 교권보호전담관 발대식”,“date”:“2026-08-22”,'
    '“description”:“10:00~12:00, 경기도교육청 조원청사 별관 2층 대강당(수원시 장안구 조원로 18)”}]';

/// 고치기 전에 실제로 들어왔던 제목의 서명 — `설문에 참여하여 **주시기 바랍니다**`.
/// `주시기 바랍니다`·`하시기 바랍니다`를 따로 적을 필요가 없다. 둘 다 이 어미를
/// 접미부로 담고 있어 `contains`가 함께 잡는다.
const _sentenceEnding = '바랍니다';

void main() {
  // ⚠️ 이 그룹이 지키는 것은 **파서 회귀**다. `_response`가 이 파일 안 `const`라
  // 프롬프트가 퇴행해도 여기서는 안 잡힌다 — 그 몫은 `ai_photo_source_kind_test`.
  group('문서 사진 실측 응답 — 파서 회귀', () {
    test('두 건이 그대로 들어온다', () {
      final parsed = parseAiScheduleJson(_response);

      expect(parsed.items.length, 2);
      expect(parsed.invalidCount, 0);
      expect(parsed.items[0].date, '2026-08-14');
      expect(parsed.items[1].date, '2026-08-22');
    });

    test('이 응답의 제목에는 경어체 서술이 없다 (기록)', () {
      final parsed = parseAiScheduleJson(_response);

      for (final item in parsed.items) {
        expect(
          item.title,
          isNot(contains(_sentenceEnding)),
          reason: '`${item.title}`은 할 일 이름이 아니라 문서 문장이다',
        );
      }
    });

    test('설문 항목이 기한 당일로 들어온다', () {
      // 문자에 적힌 것은 `8.14.(금) 12:00까지` — 시각은 버리고 그 날이 date다.
      final parsed = parseAiScheduleJson(_response);
      final survey = parsed.items.firstWhere((e) => e.date == '2026-08-14');

      expect(survey.title, contains('설문'));
      expect(survey.description, isNotNull);
    });
  });
}
