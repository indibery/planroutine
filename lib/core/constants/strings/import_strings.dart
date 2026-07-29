import '../../../features/schedule/domain/entry_kind.dart';
/// 작년 일정 가져오기(CSV) UI 문자열.
class ImportStrings {
  ImportStrings._();

  /// `/import` 화면 제목. 이 화면은 **작년 업무 CSV 전용**이다 —
  /// 행사 사진 AI는 입력 탭 히어로가 맡는다.
  static const screenTitle = '작년 업무 가져오기';
  static const description = '에듀파인 생산문서등록대장 CSV를 올리면 작년에 처리한 업무가 올해 일정으로 들어옵니다';
  static const selectFile = '파일 선택';
  static const selectFileAgain = '새 파일 가져오기';
  static const parsing = '파일 분석 중...';
  static const success = '가져오기 완료';
  static const failed = '가져오기 실패';
  static const registerAll = '전체 등록';

  /// 등록 직후 입력 탭으로 돌아가며 띄우는 안내. 등록 완료 화면에 머물 이유가
  /// 없다 — 대기 건수는 입력 탭 검토 목록이 이미 말해준다.
  static String registeredSnack(int created, int skipped) => skipped > 0
      ? '$created건을 검토 목록에 등록했어요 (중복 $skipped건 제외)'
      : '$created건을 검토 목록에 등록했어요';
  static const registerCount = '건 등록됨';

  static const csvTitle = '작년 업무 CSV 올리기';

  // AI 사진 변환 (붙여넣기 가져오기).
  //
  // 이 경로로 들어온 것은 **전부 행사**다(`registerAiSchedules`가 EntryKind.event를
  // 박는다). 그러니 히어로 제목부터 미리보기·실패 문구까지 한 낱말로 부른다 —
  // 중간에 우산말 `일정`이 끼면 같은 흐름에서 대상을 두 이름으로 부르게 된다.
  /// 복사 안내 — **어떤 사진을 찍어야 하는지**를 종류에 맞춰 말한다.
  ///
  /// 한 문구로 `일정표 사진`이라고만 하면 쪽지를 고른 사용자가 일정표를 찾아 헤맨다.
  static String aiPromptCopiedFor(EntryKind kind) => kind == EntryKind.task
      ? '프롬프트를 복사했어요. AI 앱에 쪽지·안내문 사진과 함께 붙여넣으세요'
      : '프롬프트를 복사했어요. AI 앱에 일정표 사진과 함께 붙여넣으세요';

  /// 히어로의 종류 칩 라벨. `EntryKind.label`(업무·행사)만으로는 **무엇을 찍어야
  /// 하는지**가 안 드러나 소스 문서를 말한다 — 그래서 별도 안내 줄이 필요 없다.
  static const aiSourceEvent = '행사 일정표';
  static const aiSourceTask = '업무 쪽지';

  static const aiParseEmpty = '붙여넣은 내용에서 행사를 찾지 못했어요. AI 응답(JSON)을 복사했는지 확인해 주세요';
  static const aiPreviewTitle = '붙여넣기 미리보기';
  static String aiPreviewCount(int n) => '행사 $n건 인식';
  static String aiPreviewDup(int n) => '중복 $n건 제외';
  static String aiRegisterButton(int n) => '$n건 검토 목록에 등록';
  static String aiRegistered(int n) => '$n건을 검토 목록에 등록했어요';

  // 입력 탭 히어로 — 사진 AI가 주 경로, 작년 업무 CSV는 보조 한 줄
  /// **`행사`를 떼었다.** 쪽지의 마감 기한도 이 경로로 들어오므로(업무로 저장된다)
  /// 제목이 행사라고 못박으면 사용자가 쪽지를 넣을 수 있다는 것을 모른다.
  static const heroTitle = '사진으로 넣기';
  static const heroSubtitle = '일정표나 쪽지를 찍어 AI에게 맡기세요';
  static const heroStepCopy = '① 프롬프트';
  static const heroStepAway = 'AI 앱';
  static const heroStepPaste = '② 붙여넣기';
  static const heroCsvLink = '작년 업무 가져오기 (에듀파인 CSV)';

  // 에듀파인에서 CSV 받고 가져오는 방법 가이드 (Import Initial 뷰 내 접힘 섹션)
  static const edufineGuideTitle =
      '에듀파인에서 CSV로 일정 받고 공직플랜에 적용하는 방법';

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
