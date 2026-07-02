import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/import/data/ai_schedule_parser.dart';

void main() {
  group('parseAiScheduleJson — AI 응답에서 행사 추출 (관대한 파싱)', () {
    test('깨끗한 JSON 배열 파싱', () {
      final r = parseAiScheduleJson(
        '[{"title":"입학식","date":"2026-03-02"},'
        '{"title":"봄 현장체험학습","date":"2026-04-24","description":"4-6학년"}]',
      );
      expect(r.items.length, 2);
      expect(r.items[0].title, '입학식');
      expect(r.items[0].date, '2026-03-02');
      expect(r.items[0].description, isNull);
      expect(r.items[1].description, '4-6학년');
      expect(r.invalidCount, 0);
    });

    test('```json 코드펜스와 잡담이 섞여도 배열 블록만 추출', () {
      final r = parseAiScheduleJson('''
알겠습니다! 사진 속 행사를 정리했습니다.

```json
[{"title":"입학식","date":"2026-03-02"}]
```

도움이 되었길 바랍니다.
''');
      expect(r.items.length, 1);
      expect(r.items.first.title, '입학식');
    });

    test('필수 필드 누락/형식 오류 항목은 invalidCount로 스킵', () {
      final r = parseAiScheduleJson(
        '[{"title":"입학식","date":"2026-03-02"},'
        '{"title":"","date":"2026-03-05"},' // 빈 제목
        '{"title":"날짜없음"},' // date 누락
        '{"title":"이상한날짜","date":"3월 2일"}]', // 파싱 불가 날짜
      );
      expect(r.items.length, 1);
      expect(r.invalidCount, 3);
    });

    test('날짜를 YYYY-MM-DD로 정규화 (ISO datetime·구분자 없는 형식도)', () {
      final r = parseAiScheduleJson(
        '[{"title":"A","date":"2026-03-01T09:00:00Z"},'
        '{"title":"B","date":"20260302"}]',
      );
      expect(r.items.length, 2);
      expect(r.items[0].date, '2026-03-01', reason: 'T-suffix 잘라내 정규화');
      expect(r.items[1].date, '2026-03-02', reason: '구분자 없는 형식도 정규화');
    });

    test('제목의 제어문자·개행 제거 + 길이 상한', () {
      final rlo = String.fromCharCode(0x202E);
      final r = parseAiScheduleJson(
        '[{"title":"입학$rlo-식\\n둘째줄","date":"2026-03-02"}]',
      );
      expect(r.items.length, 1);
      expect(r.items[0].title.contains(rlo), false, reason: 'RLO 제거');
      expect(r.items[0].title.contains('\n'), false, reason: '개행 제거');
    });

    test('JSON 배열이 없으면 빈 결과', () {
      final r = parseAiScheduleJson('사진이 잘 안 보여요. 다시 찍어주세요.');
      expect(r.items, isEmpty);
      expect(r.invalidCount, 0);
    });

    test('스마트 따옴표(“ ”) JSON도 파싱 — 실제 ChatGPT 복사 출력', () {
      // 2026-07-02 실기기 검증에서 GPT 응답이 스마트 따옴표로 복사돼 파싱 실패했던 케이스.
      final r = parseAiScheduleJson('''
[
{
“title”: “시업식 및 입학식”,
“date”: “2026-03-03”
},
{
“title”: “진단주간”,
“date”: “2026-03-04”,
“description”: “기간: 2026-03-04~2026-03-13”
}
]
''');
      expect(r.items.length, 2);
      expect(r.items[0].title, '시업식 및 입학식');
      expect(r.items[1].description, '기간: 2026-03-04~2026-03-13');
    });

    test('title 안의 대괄호에 속지 않고 전체 배열을 파싱', () {
      final r = parseAiScheduleJson(
        '결과: [{"title":"[중요] 입학식","date":"2026-03-02"},'
        '{"title":"졸업식","date":"2027-02-05"}] 입니다.',
      );
      expect(r.items.length, 2);
      expect(r.items.first.title, '[중요] 입학식');
    });
  });

  group('buildAiPhotoPrompt — 학년도 연도 주입', () {
    test('7월(학기 중)이면 3~12월=올해, 1~2월=내년', () {
      final p = buildAiPhotoPrompt(DateTime(2026, 7, 2));
      expect(p, contains('3~12월은 2026년'));
      expect(p, contains('1~2월은 2027년'));
    });

    test('1월(학년도 말)이면 학년도 기준 3~12월=작년, 1~2월=올해', () {
      final p = buildAiPhotoPrompt(DateTime(2027, 1, 15));
      expect(p, contains('3~12월은 2026년'));
      expect(p, contains('1~2월은 2027년'));
    });

    test('JSON 출력 형식 지시를 포함', () {
      final p = buildAiPhotoPrompt(DateTime(2026, 7, 2));
      expect(p, contains('"title"'));
      expect(p, contains('yyyy-MM-dd'));
    });
  });
}
