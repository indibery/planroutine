// 손글씨 할 일 목록 사진 — **네 모델의 실측 응답**이 파서를 통과한다.
//
// 이 프롬프트는 원래 문서(영수증·대출확인서·공문)에서 마감일을 찾는 용도였다.
// 손으로 쓴 할 일 목록을 넣었더니 세 줄 중 **한 줄만** 나왔다(2026-08-07).
//
//   ① 오늘 공직플랜 동영상 만들기
//   ② 콩나물 무침 만들기 (오늘)
//   ③ 앱 개발 서적 한권 읽기 (8월 9일까지)   ← 이것만 살아남았다
//
// 원인은 셋이었다 — 날짜의 정의가 문서 어휘(`반납예정일`·`납부기한`…)에 묶여
// `오늘`을 날짜로 안 봤고, 상대 표현을 바꾸라는 말이 없었고, 묶기 규칙이
// `같은 날짜의 여러 항목`이라 서로 다른 할 일까지 삼켰다.
//
// 아래 픽스처는 고친 프롬프트로 **실제 모델에 돌려 받은 응답 그대로**다
// (손으로 쓴 JSON이 아니다 — 리포 규칙). OCR 오차(`모험`·`종일플랜`)도 지우지
// 않는다: 그것이 현실이고, 붙여넣기 뒤 검토 단계가 잡는 몫이다.

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/import/data/ai_schedule_parser.dart';

/// 세 줄짜리 손글씨 목록에 대한 실측 응답.
const _responses = <String, String>{
  'claude':
      '[{"title": "공직플랜 동영상 만들기", "date": "2026-08-07"}, '
      '{"title": "콩나물 무침 만들기", "date": "2026-08-07"}, '
      '{"title": "앱 개발 서적 한 권 읽기", "date": "2026-08-09"}]',
  'grok':
      '[{"title": "공직플랜 동영상 만들기", "date": "2026-08-07"}, '
      '{"title": "콩나물 모험 만들기", "date": "2026-08-07"}, '
      '{"title": "앱 개발 서적 한권 읽기", "date": "2026-08-09"}]',
  'gemini': '''[
{
"title": "공직플랜 동영상 만들기",
"date": "2026-08-07"
},
{
"title": "콩나물 무침 만들기",
"date": "2026-08-07"
},
{
"title": "앱개발 서적 한권 읽기",
"date": "2026-08-09",
"description": "8월 9일까지"
}
]''',
  // GPT는 iOS 복사 과정에서 스마트 따옴표로 온다 — 파서가 정규화한다.
  'gpt': '[{“title”:“종일플랜 동영상 만들기”,“date”:“2026-08-07”},'
      '{“title”:“콩나물 무침 만들기”,“date”:“2026-08-07”},'
      '{“title”:“앱 개발 서적 한권 읽기”,“date”:“2026-08-09”}]',
};

void main() {
  group('손글씨 할 일 목록 — 실측 응답', () {
    _responses.forEach((model, raw) {
      test('$model: 세 줄이 세 건으로 들어온다', () {
        final parsed = parseAiScheduleJson(raw);

        expect(parsed.items.length, 3,
            reason: '목록의 줄 수만큼 나와야 한다 — 고치기 전에는 1건이었다');
        expect(parsed.invalidCount, 0,
            reason: '버려진 건이 있으면 사용자는 모른 채 항목을 잃는다');
      });

      test('$model: 날짜 말이 제목에 남지 않는다', () {
        final parsed = parseAiScheduleJson(raw);

        for (final item in parsed.items) {
          expect(item.title, isNot(contains('오늘')),
              reason: '`콩나물 무침 만들기 (오늘)`은 내일 보면 틀린 제목이 된다');
          expect(item.title, isNot(contains('까지')),
              reason: '`(8월 9일까지)`는 date로 옮겨갔다');
        }
      });

      test('$model: 상대 표현이 실제 날짜로 바뀐다', () {
        final parsed = parseAiScheduleJson(raw);
        final dates = parsed.items.map((i) => i.date).toList();

        // `오늘` 두 줄 + `8월 9일까지` 한 줄.
        expect(dates.where((d) => d == '2026-08-07').length, 2);
        expect(dates, contains('2026-08-09'));
      });
    });
  });
}
