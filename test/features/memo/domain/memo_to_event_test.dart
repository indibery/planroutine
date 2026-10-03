import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/memo/domain/memo_to_event.dart';

void main() {
  // 쪽지 시트는 여러 줄 입력이 기본이라, 그대로 제목으로 쓰면 일정 제목에 줄바꿈이 들어간다
  // (편집 시트 제목칸·Google/기기 저장 제목이 어색해진다). 사용자 결정(2026-10-03).
  test('첫 줄은 제목, 나머지는 설명', () {
    final r = splitMemoForEvent('운동회 물품\n줄다리기 줄 2개\n계주 바통 6개');
    expect(r.title, '운동회 물품');
    expect(r.description, '줄다리기 줄 2개\n계주 바통 6개');
  });

  test('한 줄이면 설명이 없다', () {
    final r = splitMemoForEvent('  공개수업 지도안  ');
    expect(r.title, '공개수업 지도안');
    expect(r.description, isNull);
  });

  test('앞의 빈 줄은 건너뛰고, 설명 끝의 공백은 걷어낸다', () {
    final r = splitMemoForEvent('\n\n  상담 준비 \n\n 질문 목록 \n\n');
    expect(r.title, '상담 준비');
    expect(r.description, '질문 목록');
  });

  // 빠른 입력은 한 줄이라 줄글 쪽지가 많다. 길면 앞부분만 제목으로 쓰고 글 전체는 설명에
  // 남긴다(사용자 결정 2026-10-03: 제목 상한 20자, 가능하면 띄어쓰기에서 자른다).
  group('긴 첫 줄', () {
    test('20자를 넘으면 띄어쓰기에서 잘라 …을 붙이고, 글 전체를 설명에 둔다', () {
      const text = '운동회 물품 줄다리기 줄 2개 계주 바통 6개 체육창고에서 미리 꺼내기';
      final r = splitMemoForEvent(text);
      expect(r.title, '운동회 물품 줄다리기 줄 2개 계주…');
      expect(r.description, text);
    });

    test('딱 20자면 자르지 않는다', () {
      final text = '가' * 20;
      final r = splitMemoForEvent(text);
      expect(r.title, text);
      expect(r.description, isNull);
    });

    test('띄어쓰기가 없으면 20자에서 자른다', () {
      final text = '가' * 25;
      final r = splitMemoForEvent(text);
      expect(r.title, '${'가' * 20}…');
      expect(r.description, text);
    });

    test('여러 줄인데 첫 줄이 길면 설명에 첫 줄까지 다 남긴다', () {
      final first = '나' * 25;
      final r = splitMemoForEvent('$first\n둘째 줄');
      expect(r.title, '${'나' * 20}…');
      expect(r.description, '$first\n둘째 줄');
    });
  });
}
