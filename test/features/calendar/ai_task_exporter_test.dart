import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/data/ai_task_exporter.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';

/// export 텍스트에서 ```json 코드블록의 내용을 파싱한다.
Map<String, dynamic> _extractJson(String export) {
  final start = export.indexOf('```json');
  final body = export.substring(start + '```json'.length);
  final end = body.indexOf('```');
  return jsonDecode(body.substring(0, end).trim()) as Map<String, dynamic>;
}

void main() {
  group('buildAiTaskExport', () {
    test('지시문 + JSON 코드블록을 함께 포함(하이브리드)', () {
      final e = CalendarEvent(title: '겨울방학 운영 계획', eventDate: '2026-01-03');
      final out = buildAiTaskExport(e);
      expect(out.startsWith('```'), false, reason: '지시문이 먼저 와야 함');
      expect(out, contains('```json'));
      expect(out.trim(), endsWith('```'));
    });

    test('JSON 필드가 이벤트 값과 일치', () {
      final e = CalendarEvent(
        title: '겨울방학 운영 계획',
        eventDate: '2026-01-03',
        endDate: '2026-01-05',
        description: '준비 필요',
        isAllDay: true,
      );
      final json = _extractJson(buildAiTaskExport(e));
      expect(json['title'], '겨울방학 운영 계획');
      expect(json['date'], '2026-01-03');
      expect(json['endDate'], '2026-01-05');
      expect(json['allDay'], true);
      expect(json['description'], '준비 필요');
    });

    test('endDate 없으면 null, description 없으면 빈 문자열', () {
      final e = CalendarEvent(title: 'A', eventDate: '2026-02-01');
      final json = _extractJson(buildAiTaskExport(e));
      expect(json['endDate'], isNull);
      expect(json['description'], '');
    });
  });
}
