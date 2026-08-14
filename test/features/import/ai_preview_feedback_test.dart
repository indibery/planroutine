// 붙여넣기 미리보기는 **무슨 일이 있었는지 말한다.**
//
// 파서는 형식이 어긋난 항목을 세고 있었지만(`ParsedAiSchedules.invalidCount`)
// **아무도 그 값을 읽지 않았다** — AI가 5줄을 줘도 3건만 보이고, 나머지가 어디
// 갔는지 알 길이 없었다. 손글씨 할 일 목록에서는 모든 줄이 살아남아야 하므로
// 더 문제다(2026-08-07).
//
// 함께 고친 것: 미리보기 문구가 `행사`로 고정이라 **업무 쪽지로 넣어도 행사라고**
// 떴다. 종류를 따라가게 했다.

import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/import/data/ai_schedule_parser.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

void main() {
  group('파서가 버린 건수를 셀 수 있다', () {
    test('일부만 형식 오류면 유효 건과 버린 건이 함께 나온다', () {
      final parsed = parseAiScheduleJson(
        '[{"title":"장보기","date":"2026-08-07"},'
        '{"title":"날짜없음"},'
        '{"title":"날짜깨짐","date":"내일"}]',
      );

      expect(parsed.items.length, 1);
      expect(parsed.invalidCount, 2, reason: '이 값이 화면에 안 나가면 두 건이 소리 없이 사라진다');
    });

    test('전부 형식 오류면 유효 0 · 버림 N — 빈 응답과 구분된다', () {
      final allBad = parseAiScheduleJson('[{"title":"장보기"}]');
      expect(allBad.items, isEmpty);
      expect(allBad.invalidCount, 1);

      // JSON 자체가 없으면 버린 것도 없다. 사용자가 할 일이 다르다 —
      // 이쪽은 다시 복사해야 하고, 위쪽은 AI에 다시 요청해야 한다.
      final noJson = parseAiScheduleJson('사진이 잘 안 보여요');
      expect(noJson.items, isEmpty);
      expect(noJson.invalidCount, 0);
    });
  });

  group('문구가 종류를 따라간다', () {
    test('넣은 건수 — 업무 쪽지에 행사라고 하지 않는다', () {
      expect(
        ImportStrings.aiRegisterSummary(
          EntryKind.task,
          created: 3,
          dup: 0,
          skipped: 0,
        ),
        contains('업무'),
      );
      expect(
        ImportStrings.aiRegisterSummary(
          EntryKind.event,
          created: 3,
          dup: 0,
          skipped: 0,
        ),
        contains('행사'),
      );
      expect(
        ImportStrings.aiRegisterSummary(
          EntryKind.task,
          created: 3,
          dup: 0,
          skipped: 0,
        ),
        isNot(contains('행사')),
        reason: '예전에는 `행사 3건 인식`으로 고정이었다',
      );
    });

    test('못 찾았을 때도 종류를 따라간다', () {
      expect(ImportStrings.aiParseEmptyFor(EntryKind.task), contains('업무'));
      expect(ImportStrings.aiParseEmptyFor(EntryKind.event), contains('행사'));
    });

    test('종류 이름을 여기 다시 박지 않는다 — EntryKind.label에서 온다', () {
      // 용어가 바뀌면 배지·칩만 따라가고 이 문구만 옛 이름으로 남는 사고가
      // 이 리포에 있었다(일괄 등록 pill).
      for (final kind in EntryKind.values) {
        expect(
          ImportStrings.aiRegisterSummary(kind, created: 1, dup: 0, skipped: 0),
          contains(kind.label),
        );
      }
    });
  });

  // 시트를 없앤 뒤로 이 한 줄이 시트 부제가 하던 말을 전부 진다
  // (인식 건수 · 중복 제외 · 형식 오류 건너뜀).
  group('결과 한 줄이 미리보기 시트를 대신한다', () {
    test('중복도 형식 오류도 없으면 넣은 건수만 말한다', () {
      final msg = ImportStrings.aiRegisterSummary(
        EntryKind.event,
        created: 2,
        dup: 0,
        skipped: 0,
      );

      expect(msg, contains('2'));
      expect(msg, isNot(contains('중복')), reason: '0건인 말은 붙이지 않는다');
      expect(msg, isNot(contains('형식')));
    });

    test('중복과 형식 오류가 있으면 한 줄에 함께 말한다', () {
      final msg = ImportStrings.aiRegisterSummary(
        EntryKind.event,
        created: 1,
        dup: 2,
        skipped: 3,
      );

      expect(msg, contains(ImportStrings.aiPreviewDup(2)));
      expect(msg, contains(ImportStrings.aiPreviewSkipped(3)));
    });

    test('새로 넣은 게 없어도 조용히 지나가지 않는다', () {
      // 시트가 사라져 이 문구가 "붙여넣기가 됐다"는 유일한 신호다.
      // 전부 중복이면 목록이 그대로라 화면만 봐서는 눌린 건지 알 수 없다.
      final msg = ImportStrings.aiRegisterSummary(
        EntryKind.event,
        created: 0,
        dup: 3,
        skipped: 0,
      );

      expect(msg, isNotEmpty);
      expect(msg, contains(ImportStrings.aiPreviewDup(3)));
    });
  });

  group('버린 건수 문구', () {
    test('건수를 그대로 말한다', () {
      expect(ImportStrings.aiPreviewSkipped(2), contains('2'));
    });

    test('전부 버렸을 때는 다시 요청하라고 말한다', () {
      final msg = ImportStrings.aiParseAllInvalid(3);

      expect(msg, contains('3'));
      // "붙여넣기를 다시 하세요"가 아니다 — 클립보드는 멀쩡했고 내용이 문제다.
      expect(msg, contains('다시 요청'));
    });
  });
}
