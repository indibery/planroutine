import 'dart:convert';

import '../../../core/utils/date_utils.dart' as du;
import '../../schedule/domain/entry_kind.dart';

/// AI가 사진에서 뽑아준 행사 한 건.
class AiScheduleItem {
  const AiScheduleItem({required this.title, required this.date, this.description});

  final String title;

  /// yyyy-MM-dd
  final String date;
  final String? description;
}

/// 파싱 결과 — 유효 항목과 스킵된(형식 오류) 건수.
class ParsedAiSchedules {
  const ParsedAiSchedules({required this.items, required this.invalidCount});

  final List<AiScheduleItem> items;
  final int invalidCount;
}

/// AI 응답 텍스트에서 일정 JSON 배열을 관대하게 추출한다.
/// 코드펜스(```json)·인사말이 섞여 있어도 첫 번째 유효한 JSON 배열을 찾고,
/// iOS/ChatGPT 복사 과정에서 생기는 스마트 따옴표(“ ” ‘ ’)는 표준 따옴표로
/// 정규화한다(실기기 검증에서 GPT 출력이 이걸로 파싱 실패했던 실사례).
/// 순수 함수 — 플랫폼/DB 무관.
ParsedAiSchedules parseAiScheduleJson(String text) {
  final normalized = text
      .replaceAll('“', '"') // “
      .replaceAll('”', '"') // ”
      .replaceAll('‘', "'") // ‘
      .replaceAll('’', "'"); // ’
  final decoded = _extractFirstJsonArray(normalized);
  if (decoded == null) {
    return const ParsedAiSchedules(items: [], invalidCount: 0);
  }

  final items = <AiScheduleItem>[];
  var invalid = 0;
  for (final entry in decoded) {
    if (entry is! Map) {
      invalid++;
      continue;
    }
    final rawTitle = entry['title'];
    final rawDate = entry['date'];
    if (rawTitle is! String || rawDate is! String) {
      invalid++;
      continue;
    }
    final title = _sanitize(rawTitle);
    final parsedDate = DateTime.tryParse(rawDate);
    if (title.isEmpty || parsedDate == null) {
      invalid++;
      continue;
    }
    final rawDesc = entry['description'];
    final desc = rawDesc is String ? _sanitize(rawDesc) : '';
    items.add(AiScheduleItem(
      title: title,
      // 다른 삽입 경로와 동일하게 YYYY-MM-DD로 정규화 — 월별조회·중복체크 불변식 유지.
      date: du.formatDate(parsedDate),
      description: desc.isEmpty ? null : desc,
    ));
  }
  return ParsedAiSchedules(items: items, invalidCount: invalid);
}

/// AI 문자열 무해화 — 제어문자·개행 제거, 양방향/제로폭 문자 제거, 공백 정리, 길이 상한.
String _sanitize(String raw) {
  final s = raw
      .replaceAll(RegExp('[\u0000-\u001F\u007F]'), ' ') // control chars
      .replaceAll(
          RegExp('[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]'),
          '') // bidi override / zero-width
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return s.length > 200 ? s.substring(0, 200) : s;
}

/// 텍스트에서 첫 번째 균형 잡힌 `[...]` 블록을 찾아 JSON 배열로 디코드.
/// 문자열 내부의 대괄호("[중요]" 등)는 건너뛴다. 실패 시 다음 `[`부터 재시도.
List<dynamic>? _extractFirstJsonArray(String text) {
  var searchFrom = 0;
  while (true) {
    final start = text.indexOf('[', searchFrom);
    if (start == -1) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '[') {
        depth++;
      } else if (ch == ']') {
        depth--;
        if (depth == 0) {
          try {
            final decoded = jsonDecode(text.substring(start, i + 1));
            if (decoded is List) return decoded;
          } catch (_) {
            // 유효한 JSON이 아니면 다음 '['부터 재시도
          }
          break;
        }
      }
    }
    searchFrom = start + 1;
  }
}

/// 사진 변환용 프롬프트. [now] 기준 학년도(3월 시작)에 맞춰 연도 규칙을 주입한다.
/// 고정 문구 — 사용자가 포맷을 몰라도 복사 한 번으로 AI가 정확한 JSON을 내게 한다.
///
/// [kind]가 **소스 문서의 종류**를 결정한다.
///
/// 두 프롬프트로 갈라 쓰는 이유는 **읽는 대상이 다르기** 때문이다. 일정표는 표에서
/// 모든 행을 뽑는 일이고, 쪽지·공문은 산문에서 기한이 적힌 문장만 골라내는 일이다.
/// 한 프롬프트로 둘을 다 지시하면 표에서 엉뚱한 항목을 기한으로 읽거나 쪽지에서
/// 기한 아닌 문장을 일정으로 만든다.
///
/// [kind]는 등록 종류도 함께 결정한다(`registerAiSchedules`) — 한 선택이 두 곳을
/// 정해야 "쪽지 프롬프트로 뽑았는데 행사로 저장"이 생기지 않는다.
String buildAiPhotoPrompt(DateTime now, {EntryKind kind = EntryKind.event}) {
  final schoolYear = now.month >= 3 ? now.year : now.year - 1;
  final yearRule =
      '- 날짜에 연도가 없으면 3~12월은 $schoolYear년, 1~2월은 ${schoolYear + 1}년으로 합니다. (학년도 기준)';

  // 소스 문서를 설명하는 말은 **UI 용어에 맞추지 않는다** — 청중이 AI이고, 우리 분류에
  // 맞춰 고치면 추출 품질이 흔들린다(CLAUDE.md의 용어 예외).
  if (kind == EntryKind.task) {
    return '''
첨부한 사진은 학교에서 받은 쪽지·안내문·공문입니다. 본문에서 **처리 기한이 있는 일**만 찾아 아래 JSON 배열로만 출력하세요. 설명·인사말 없이 JSON만 출력합니다.

[{"title": "할 일 이름", "date": "yyyy-MM-dd", "description": "근거가 된 문구(없으면 생략)"}]

규칙:
$yearRule
- `~까지`, `마감`, `기한`, `제출`, `신청`, `회신`, `까지 알려`처럼 **언제까지 해야 하는지**가 적힌 것만 뽑습니다.
- date는 **마감일**입니다. `10월 15일까지 제출`이면 10월 15일입니다.
- 기간이 적혀 있으면(예: 10.13~10.17 신청) **마지막 날**을 date로 합니다.
- title은 내가 할 일로 씁니다. `방과후 신청서 제출`처럼 동작이 드러나게 합니다.
- 행사 안내(운동회·학예회 등)만 있고 내가 처리할 기한이 없으면 그 항목은 건너뜁니다.
- 기한이 하나도 없으면 빈 배열 `[]`을 출력합니다.
- 읽을 수 없는 항목은 건너뜁니다.''';
  }

  return '''
첨부한 사진은 학교 월간·연간 일정표입니다. 표에 있는 모든 일정을 아래 JSON 배열로만 출력하세요. 설명·인사말 없이 JSON만 출력합니다.

[{"title": "일정 이름", "date": "yyyy-MM-dd", "description": "비고(없으면 생략)"}]

규칙:
$yearRule
- 기간 일정(예: 3.16~3.20)은 시작일 기준 1건으로 하고 기간을 description에 적습니다.
- 읽을 수 없는 항목은 건너뜁니다.''';
}
