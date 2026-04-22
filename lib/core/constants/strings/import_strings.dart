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

  // 에듀파인에서 CSV 받고 가져오는 방법 가이드 (Import Initial 뷰 내 접힘 섹션)
  static const edufineGuideTitle = '에듀파인에서 CSV 받는 방법';

  // ── 1단: CSV 다운받기 ─────────────────────────────────
  static const edufineGuideSection1Title = '① CSV 다운받기';
  static const edufineGuideSection1Steps = <String>[
    '문서관리 → 문서함 → 문서등록대장(다년도검색)',
    '등록 일자 범위 지정 (예: 2024-03-01 ~ 2025-02-28)',
    '기안(접수)자에 본인 이름 입력',
    '"조회" → 결과 표 상단 저장 메뉴 → "CSV다운(과제정보추가)"',
  ];

  // ── 2단: 아이폰으로 가져오기 (A/B 중 택1) ─────────────
  static const edufineGuideSection2Title = '② 아이폰으로 가져오기';
  static const edufineGuideSection2Hint = '아래 둘 중 편한 방법을 선택하세요.';

  static const edufineGuideMethodATitle = 'A. 공유시트로 바로 가져오기 (권장)';
  static const edufineGuideMethodASteps = <String>[
    '카카오톡 "나와의 채팅" 또는 이메일로 CSV 파일 전송',
    '아이폰에서 파일 탭 → 공유(↑) 아이콘',
    '앱 목록에서 "공직플랜" 선택',
  ];
  static const edufineGuideMethodATip =
      '공직플랜이 보이지 않으면 앱 목록 오른쪽 끝의 "더 보기" 또는 "···"를 탭해 찾으세요. (AirDrop·메일로 받은 파일에서도 동일한 방법)';

  static const edufineGuideMethodBTitle = 'B. 파일 앱에 저장해 "파일 선택"으로';
  static const edufineGuideMethodBSteps = <String>[
    'iCloud/AirDrop/메일 첨부 등으로 CSV를 아이폰 파일 앱에 저장',
    '위 "파일 선택" 버튼 탭 → 파일 앱에서 CSV 선택',
  ];
}
