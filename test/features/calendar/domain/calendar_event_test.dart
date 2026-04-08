import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';

void main() {
  group('CalendarEvent', () {
    group('fromMap / toMap 라운드트립', () {
      test('모든 필드가 있는 경우 정상 변환', () {
        final map = {
          'id': 1,
          'title': '교직원 회의',
          'description': '3월 정기 회의',
          'event_date': '2026-03-15',
          'end_date': '2026-03-15',
          'is_all_day': 1,
          'color': '#4A6FA5',
          'schedule_id': 10,
          'created_at': '2026-03-01T09:00:00.000',
          'updated_at': '2026-03-01T09:00:00.000',
        };

        final event = CalendarEvent.fromMap(map);
        final result = event.toMap();

        expect(result['id'], 1);
        expect(result['title'], '교직원 회의');
        expect(result['description'], '3월 정기 회의');
        expect(result['event_date'], '2026-03-15');
        expect(result['end_date'], '2026-03-15');
        expect(result['is_all_day'], 1);
        expect(result['color'], '#4A6FA5');
        expect(result['schedule_id'], 10);
        expect(result['created_at'], '2026-03-01T09:00:00.000');
        expect(result['updated_at'], '2026-03-01T09:00:00.000');
      });

      test('선택 필드가 null인 경우', () {
        final map = {
          'id': null,
          'title': '수업 준비',
          'description': null,
          'event_date': '2026-04-08',
          'end_date': null,
          'is_all_day': 1,
          'color': null,
          'schedule_id': null,
          'created_at': '2026-04-01T10:00:00.000',
          'updated_at': '2026-04-01T10:00:00.000',
        };

        final event = CalendarEvent.fromMap(map);

        expect(event.id, isNull);
        expect(event.title, '수업 준비');
        expect(event.description, isNull);
        expect(event.endDate, isNull);
        expect(event.color, isNull);
        expect(event.scheduleId, isNull);
      });

      test('is_all_day가 0이면 false', () {
        final map = {
          'title': '오후 수업',
          'event_date': '2026-04-08',
          'is_all_day': 0,
          'created_at': '2026-04-01T10:00:00.000',
          'updated_at': '2026-04-01T10:00:00.000',
        };

        final event = CalendarEvent.fromMap(map);
        expect(event.isAllDay, false);

        final result = event.toMap();
        expect(result['is_all_day'], 0);
      });
    });

    group('색상 변환', () {
      test('6자리 hex 문자열을 Color로 변환', () {
        final event = CalendarEvent(
          title: '테스트',
          eventDate: '2026-04-08',
          color: '#EF4444',
        );

        expect(event.eventColor, const Color(0xFFEF4444));
      });

      test('8자리 hex 문자열을 Color로 변환', () {
        final event = CalendarEvent(
          title: '테스트',
          eventDate: '2026-04-08',
          color: '#FF10B981',
        );

        expect(event.eventColor, const Color(0xFF10B981));
      });

      test('color가 null이면 기본 색상 반환', () {
        final event = CalendarEvent(
          title: '테스트',
          eventDate: '2026-04-08',
        );

        expect(event.eventColor, const Color(0xFF4A6FA5));
      });

      test('color가 빈 문자열이면 기본 색상 반환', () {
        final event = CalendarEvent(
          title: '테스트',
          eventDate: '2026-04-08',
          color: '',
        );

        expect(event.eventColor, const Color(0xFF4A6FA5));
      });

      test('colorToHex 변환', () {
        final hex = CalendarEvent.colorToHex(const Color(0xFFEF4444));
        expect(hex, '#EF4444');
      });
    });

    group('날짜 파싱', () {
      test('eventDateTime 변환', () {
        final event = CalendarEvent(
          title: '테스트',
          eventDate: '2026-04-08',
        );

        final dt = event.eventDateTime;
        expect(dt.year, 2026);
        expect(dt.month, 4);
        expect(dt.day, 8);
      });

      test('endDateTime 변환 - endDate가 있는 경우', () {
        final event = CalendarEvent(
          title: '테스트',
          eventDate: '2026-04-08',
          endDate: '2026-04-10',
        );

        final dt = event.endDateTime;
        expect(dt.year, 2026);
        expect(dt.month, 4);
        expect(dt.day, 10);
      });

      test('endDateTime 변환 - endDate가 null이면 시작일 반환', () {
        final event = CalendarEvent(
          title: '테스트',
          eventDate: '2026-04-08',
        );

        final dt = event.endDateTime;
        expect(dt.year, 2026);
        expect(dt.month, 4);
        expect(dt.day, 8);
      });
    });

    group('toMap id 처리', () {
      test('id가 null이면 map에 id 미포함', () {
        final event = CalendarEvent(
          title: '새 이벤트',
          eventDate: '2026-04-08',
        );

        final map = event.toMap();
        expect(map.containsKey('id'), false);
      });

      test('id가 있으면 map에 id 포함', () {
        final event = CalendarEvent(
          id: 5,
          title: '기존 이벤트',
          eventDate: '2026-04-08',
        );

        final map = event.toMap();
        expect(map['id'], 5);
      });
    });
  });
}
