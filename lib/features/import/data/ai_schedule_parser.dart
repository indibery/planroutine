import 'dart:convert';

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

/// AI 응답 텍스트에서 행사 JSON 배열을 관대하게 추출한다.
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
    final title = entry['title'];
    final date = entry['date'];
    if (title is! String || title.trim().isEmpty || date is! String) {
      invalid++;
      continue;
    }
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) {
      invalid++;
      continue;
    }
    final description = entry['description'];
    items.add(AiScheduleItem(
      title: title.trim(),
      date: date,
      description: description is String && description.trim().isNotEmpty
          ? description.trim()
          : null,
    ));
  }
  return ParsedAiSchedules(items: items, invalidCount: invalid);
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
/// v1 고정 문구 — 사용자가 포맷을 몰라도 복사 한 번으로 AI가 정확한 JSON을 내게 한다.
String buildAiPhotoPrompt(DateTime now) {
  final schoolYear = now.month >= 3 ? now.year : now.year - 1;
  return '''
첨부한 사진은 학교 연간 행사 일정표입니다. 표에 있는 모든 행사를 아래 JSON 배열로만 출력하세요. 설명·인사말 없이 JSON만 출력합니다.

[{"title": "행사명", "date": "yyyy-MM-dd", "description": "비고(없으면 생략)"}]

규칙:
- 날짜에 연도가 없으면 3~12월은 $schoolYear년, 1~2월은 ${schoolYear + 1}년으로 합니다. (학년도 기준)
- 기간 행사(예: 3.16~3.20)는 시작일 기준 1건으로 하고 기간을 description에 적습니다.
- 읽을 수 없는 항목은 건너뜁니다.''';
}
