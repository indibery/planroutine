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
  'gpt':
      '[{“title”:“종일플랜 동영상 만들기”,“date”:“2026-08-07”},'
      '{“title”:“콩나물 무침 만들기”,“date”:“2026-08-07”},'
      '{“title”:“앱 개발 서적 한권 읽기”,“date”:“2026-08-09”}]',
};

/// 30일 창 검증용 — **경계를 넘나드는 다섯 줄**의 실측 응답.
///
///   회비 내기 (8월 5일)       3일 전   → 창 안, 그대로
///   도서관 책 반납 (7월 20일)  19일 전  → 창 안, 그대로
///   건강검진 예약 (6월 10일)   59일 전  → 창 밖, 내년으로
///   학부모 상담 준비 (8월 20일)         → 앞날
///   교재 주문                 날짜 없음 → 오늘
///
/// 오늘은 2026-08-08이었다. "며칠 전인지 세는 계산이 AI에게 어려울 것"이라고
/// 걱정했는데 두 모델 다 정확히 갈랐다 — 걱정이 틀렸다는 것도 기록해 둔다.
const _windowResponses = <String, String>{
  'gemini': """[
{ "title": "회비 내기", "date": "2026-08-05" },
{ "title": "도서관 책 반납", "date": "2026-07-20" },
{ "title": "건강검진 예약", "date": "2027-06-10" },
{ "title": "학부모 상담 준비", "date": "2026-08-20" },
{ "title": "교재 주문", "date": "2026-08-08" }
]""",
  'gpt':
      '[{“title”:“회비 내기”,“date”:“2026-08-05”},'
      '{“title”:“도서관 책 반납”,“date”:“2026-07-20”},'
      '{“title”:“건강검진 예약”,“date”:“2027-06-10”},'
      '{“title”:“학부모 상담 준비”,“date”:“2026-08-20”},'
      '{“title”:“교재 주문”,“date”:“2026-08-08”}]',
};

void main() {
  group('손글씨 할 일 목록 — 실측 응답', () {
    _responses.forEach((model, raw) {
      test('$model: 세 줄이 세 건으로 들어온다', () {
        final parsed = parseAiScheduleJson(raw);

        expect(
          parsed.items.length,
          3,
          reason: '목록의 줄 수만큼 나와야 한다 — 고치기 전에는 1건이었다',
        );
        expect(parsed.invalidCount, 0, reason: '버려진 건이 있으면 사용자는 모른 채 항목을 잃는다');
      });

      test('$model: 날짜 말이 제목에 남지 않는다', () {
        final parsed = parseAiScheduleJson(raw);

        for (final item in parsed.items) {
          expect(
            item.title,
            isNot(contains('오늘')),
            reason: '`콩나물 무침 만들기 (오늘)`은 내일 보면 틀린 제목이 된다',
          );
          expect(
            item.title,
            isNot(contains('까지')),
            reason: '`(8월 9일까지)`는 date로 옮겨갔다',
          );
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

  group('30일 창 — 최근 지난 날짜는 밀지 않는다', () {
    _windowResponses.forEach((model, raw) {
      test('$model: 경계가 갈린다', () {
        final parsed = parseAiScheduleJson(raw);
        expect(parsed.items.length, 5);
        expect(parsed.invalidCount, 0);

        final byTitle = {for (final i in parsed.items) i.title: i.date};

        // 창 안 — 지난 날 그대로. 1년 뒤로 밀면 오늘 탭의 `기한이 지난` 구역에
        // 들어가지 못하고 내년 할 일이 된다.
        expect(byTitle['회비 내기'], '2026-08-05', reason: '3일 전');
        expect(byTitle['도서관 책 반납'], '2026-07-20', reason: '19일 전');

        // 창 밖 — 내년으로. 이 한 줄이 창이 실제로 작동한다는 증거다.
        expect(byTitle['건강검진 예약'], '2027-06-10', reason: '59일 전이라 내년');

        expect(byTitle['학부모 상담 준비'], '2026-08-20', reason: '앞날은 그대로');
        expect(byTitle['교재 주문'], '2026-08-08', reason: '날짜 없는 줄은 오늘');
      });
    });
  });
}
