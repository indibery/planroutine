/// 작년 일정 가져오기(CSV) UI 문자열.
class ImportStrings {
  ImportStrings._();

  static const description = 'CSV 파일을 업로드해 작년 업무 일정을 불러옵니다';
  static const selectFile = '파일 선택';
  static const selectFileAgain = '새 파일 가져오기';
  static const parsing = '파일 분석 중...';
  static const success = '가져오기 완료';
  static const failed = '가져오기 실패';
  static const registerAll = '전체 등록';
  static const registerCount = '건 등록됨';

  // 에듀파인에서 CSV 받는 방법 가이드 (Import Initial 뷰 내 접힘 섹션)
  static const edufineGuideTitle = '에듀파인에서 CSV 받는 방법';
  static const edufineGuideSteps = <String>[
    '문서관리 → 문서함 → 문서등록대장(다년도검색) 진입',
    '가져올 문서 기간 범위 지정 (예: 2024-03-01 ~ 2025-02-28)',
    '기안(접수)자에 본인 이름 입력',
    '우측 상단 "조회" 버튼 클릭',
    '결과 표 상단 저장 메뉴에서 "CSV다운(과제정보추가)" 선택',
    'PC에서 카카오톡 "나와의 채팅"에 CSV 파일 전송',
    'iPhone 카카오톡에서 파일 탭 → 공유 → "공직플랜"으로 열기',
  ];
}
