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

/// 사진 변환용 프롬프트. 고정 문구 — 사용자가 포맷을 몰라도 복사 한 번으로 AI가
/// 정확한 JSON을 내게 한다.
///
/// [kind]가 **소스 문서의 종류**를 결정한다.
///
/// **연도 규칙이 종류마다 다르다.** 행사는 학년도(3월~다음 2월이 한 덩어리)를 쓰고,
/// 업무는 **오늘 이후 가장 가까운 그 날짜**를 쓴다. 처음엔 두 프롬프트가 학년도 규칙을
/// 공유했는데 그건 마감·기한에 틀렸다(사용자 지적 2026-07-29):
///
/// - 2027년 **5월**에 찍은 쪽지에 `1월 20일까지` → 학년도는 2027이므로 `1~2월은 2028년`
///   → **2028-01-20**. 8개월 뒤가 된다.
/// - 2027년 **1월**에 찍은 것에 `12월 3일` → 학년도는 2026이므로 `3~12월은 2026년`
///   → **2026-12-03**, 즉 **이미 지난 날**로 들어간다.
///
/// 학년도는 학사일정이 3월에 시작해 다음 2월에 끝나는 한 덩어리라서 성립하는 규칙이다.
/// 마감은 그런 덩어리가 없고 **다음에 오는 그 날**이 답이다. 그래서 업무 프롬프트에는
/// 오늘 날짜를 주고 상대적으로 판단하게 한다.
///
/// 두 프롬프트로 갈라 쓰는 이유는 **읽는 대상이 다르기** 때문이다. 일정표는 표에서
/// 모든 행을 뽑는 일이고, 쪽지·공문은 산문에서 기한이 적힌 문장만 골라내는 일이다.
/// 한 프롬프트로 둘을 다 지시하면 표에서 엉뚱한 항목을 기한으로 읽거나 쪽지에서
/// 기한 아닌 문장을 일정으로 만든다.
///
/// [kind]는 등록 종류도 함께 결정한다(`registerAiSchedules`) — 한 선택이 두 곳을
/// 정해야 "쪽지 프롬프트로 뽑았는데 행사로 저장"이 생기지 않는다.
///
/// **업무 쪽 프롬프트는 학교에 묶지 않는다.** 처음엔 `학교에서 받은 쪽지·안내문·
/// 공문입니다`로 시작했는데, 실사용 예가 **도서관 대출 확인 화면**이었다(사용자 사진
/// 2026-07-29). 소스를 좁히면 AI가 "이건 대상이 아니다"로 판단할 수 있고, 기한 낱말을
/// `마감·제출·신청`으로만 열거하면 `반납예정일`·`납부기한`처럼 그 낱말이 없는 표현을
/// 놓친다. 그래서 **"내가 해야 할 일 · 기억해야 할 날"** 로 넓히고 낱말을 예시로 준다.
///
/// 그 사진으로 규칙을 대조한 결과(기대값): 책 2권이 같은 `반납예정일 08.12`이므로
/// `{"title": "도서 2권 반납", "date": "2026-08-12"}` 한 건. `대출일 07.29`는 이미
/// 끝난 일이라 뽑지 않는다.
String buildAiPhotoPrompt(DateTime now, {EntryKind kind = EntryKind.event}) {
  final schoolYear = now.month >= 3 ? now.year : now.year - 1;
  final today = du.formatDate(now);

  // 소스 문서를 설명하는 말은 **UI 용어에 맞추지 않는다** — 청중이 AI이고, 우리 분류에
  // 맞춰 고치면 추출 품질이 흔들린다(CLAUDE.md의 용어 예외).
  if (kind == EntryKind.task) {
    final tomorrow = du.formatDate(now.add(const Duration(days: 1)));
    // 최근 지난 날짜 예시 — **계산해서 넣는다.** 고정 문자열로 두면 오늘이
    // 언제냐에 따라 규칙과 모순된다(아래 연도 규칙 주석 참고).
    final recent = now.subtract(const Duration(days: 3));
    final recentDate = du.formatDate(recent);
    final recentMd = '${recent.month}월 ${recent.day}일';
    return '''
첨부한 사진에서 **내가 해야 할 일**과 **기억해야 할 날**을 찾아 아래 JSON 배열로만 출력하세요. 설명·인사말 없이 JSON만 출력합니다.

[{"title": "할 일 이름", "date": "yyyy-MM-dd", "description": "자세한 내용(없으면 생략)"}]

먼저 사진이 어느 쪽인지 봅니다.

**(가) 할 일을 적어둔 목록·메모라면** — 손글씨 메모, 체크리스트, 불릿 목록
- 적힌 항목을 **하나도 빠짐없이, 한 줄에 한 건씩** 뽑습니다.
- 고르거나 합치지 않습니다. 서로 다른 할 일은 날짜가 같아도 따로 둡니다.
- 날짜가 안 적힌 줄은 오늘 날짜로 합니다.

**(나) 그 밖의 문서라면** — 사진은 무엇이든 될 수 있습니다. 안내문, 쪽지, 공문, 영수증, 대출·예약 확인 화면, 문자·메신저 캡처, 청구서.
- **날짜가 있고, 그 날짜에 내가 무언가 해야 하거나 기억해야 하는 것**만 뽑습니다.
  예: `반납예정일`, `납부기한`, `유효기간`, `만료일`, `예약일`, `방문일`, `마감`, `제출`, `신청`, `회신`, `~까지`, `점검일`, `수령일`.
- **행사·안내만 있고 내가 할 일이 없으면** 건너뜁니다. 남이 하는 일, 이미 끝난 일도 건너뜁니다. 날짜를 알 수 없어도 건너뜁니다.
- **같은 항목이** 같은 날짜로 여러 개면(예: 책 2권이 같은 날 반납) **한 건으로 묶고** 개수를 title에 적습니다.

공통 규칙:
- 오늘은 $today입니다.
- `오늘`은 $today, `내일`은 $tomorrow처럼 상대 표현도 실제 날짜로 바꿉니다.
- 연도가 적혀 있지 않으면 **오늘 이후 가장 가까운** 그 날짜로 합니다.
  월·일만 적힌 날짜(`08.12`, `1월 20일`)는 오늘부터 세어 **아직 오지 않은 첫 번째** 그 날짜입니다 — 올해 안에 아직 온다면 올해, 이미 지났다면 내년입니다.
- 다만 **최근 30일 안에 지난 날짜는 이미 지난 날 그대로** 둡니다. 1년 뒤로 밀지 않습니다.
  (오늘이 $today이면 `$recentMd`은 $recentDate입니다 — 사흘 전입니다.)
- `~까지`, `마감`, `기한`이면 그 **마지막 날**을 date로 합니다.
- 기간이 적혀 있으면(예: 10.13~10.17 신청) **마지막 날**을 date로 합니다 — 놓치면 안 되는 날이 끝나는 날입니다.
- date는 반드시 채웁니다. 빈 문자열이나 생략은 안 됩니다.
- title은 사진에 적힌 할 일 문구를 **그대로** 씁니다. 줄이거나 바꿔 쓰지 않습니다.
- 다만 **날짜를 가리키는 말은 title에서 뺍니다.** `(오늘)`, `(8월 9일까지)` 같은 표현은 date로 옮겨갔으므로 제목에 남기지 않습니다.
  `장보기 (오늘)` → `장보기` / `보고서 제출 (8월 9일까지)` → `보고서 제출`
- description에는 **자세한 내용**을 적습니다 — 묶은 항목의 이름(책 제목 등), 금액, 장소, 근거가 된 문구.
  날짜만 되풀이하지 않습니다.
- 뽑을 것이 하나도 없으면 빈 배열 `[]`을 출력합니다.
- 읽을 수 없는 항목은 건너뜁니다.''';
  }

  return '''
첨부한 사진은 학교 월간·연간 일정표입니다. 표에 있는 모든 일정을 아래 JSON 배열로만 출력하세요. 설명·인사말 없이 JSON만 출력합니다.

[{"title": "일정 이름", "date": "yyyy-MM-dd", "description": "비고(없으면 생략)"}]

규칙:
- **일정표에 학년도나 연도가 적혀 있으면 그것을 따릅니다.** 표 제목·머리글을 먼저 보세요.
  예: `${schoolYear + 1}학년도`라고 적혀 있으면 3~12월은 ${schoolYear + 1}년, 1~2월은 ${schoolYear + 2}년입니다.
  `${schoolYear + 1}년 3월`처럼 연월이 적혀 있으면 그 연도를 그대로 씁니다.
- 적혀 있지 않을 때만 3~12월은 $schoolYear년, 1~2월은 ${schoolYear + 1}년으로 합니다. (학년도 기준)
- 기간 일정(예: 3.16~3.20)은 시작일 기준 1건으로 하고 기간을 description에 적습니다.
- 읽을 수 없는 항목은 건너뜁니다.''';
}
