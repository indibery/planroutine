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
}
