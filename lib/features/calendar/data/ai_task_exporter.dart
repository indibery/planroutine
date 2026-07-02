import 'dart:convert';

import '../domain/calendar_event.dart';

/// 외부 AI에게 붙여넣을 지시문. 이 일정으로 무엇을 해달라는지 프라이밍한다.
/// v1 고정(편집 없음).
const String _aiTaskInstruction =
    '아래는 제 업무 일정 한 건입니다. 이 일정을 처리하는 데 필요한 것을 도와주세요 — '
    '관련 문서·메일 초안 작성, 준비물·체크리스트 정리 등 실행 가능한 형태로 제안해 주세요.';

/// 단일 캘린더 이벤트를 외부 AI 자동화용 하이브리드(지시문 + JSON) 텍스트로 만든다.
/// 공유시트로 전달해 사용자가 외부 AI에 넘긴다. 순수 함수 — 플랫폼/DB 무관.
String buildAiTaskExport(CalendarEvent event) {
  final data = <String, dynamic>{
    'title': event.title,
    'date': event.eventDate,
    'endDate': event.endDate,
    'allDay': event.isAllDay,
    'description': event.description ?? '',
  };
  const encoder = JsonEncoder.withIndent('  ');
  final jsonBlock = encoder.convert(data);
  return '$_aiTaskInstruction\n\n```json\n$jsonBlock\n```';
}
