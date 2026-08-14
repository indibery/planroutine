import '../../../features/schedule/domain/entry_kind.dart';

/// 작년 일정 가져오기(CSV) UI 문자열.
class ImportStrings {
  ImportStrings._();

  /// `/import` 화면 제목. 이 화면은 **작년 업무 CSV 전용**이다 —
  /// 행사 사진 AI는 입력 탭 히어로가 맡는다.
  static const screenTitle = '작년 업무 가져오기';
  static const description = '에듀파인 생산문서등록대장 CSV를 올리면 작년에 처리한 업무가 올해 일정으로 들어옵니다';

  /// 온보딩 첫 장 본문. **처음 쓰는 사람에게 이 한 줄이 CSV 경로 소개다** —
  /// 여기서 시스템 이름을 틀리면 엉뚱한 곳에서 파일을 찾는다.
  /// 짧은 형태는 [heroCsvLink]와 같은 `에듀파인 CSV`로 맞춘다.
  static const onboardingCsvBody = '에듀파인 CSV를 업로드하면\n작년 업무 일정이 자동 등록됩니다';
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
      ? '프롬프트를 복사했어요. AI 앱에 사진과 함께 붙여넣으세요 (쪽지·영수증·확인 화면 등)'
      : '프롬프트를 복사했어요. AI 앱에 일정표 사진과 함께 붙여넣으세요';

  /// 히어로의 종류 칩 라벨. `EntryKind.label`(업무·행사)만으로는 **무엇을 찍어야
  /// 하는지**가 안 드러나 무엇을 찍는지를 말한다 — 그래서 별도 안내 줄이 필요 없다.
  ///
  /// **`쪽지`라고 못박지 않는다.** 이 경로가 받는 것은 학교 문서만이 아니다 —
  /// 도서관 반납예정일, 납부기한, 유효기간처럼 **날짜가 있고 내가 해야 하는 일**이면
  /// 무엇이든 된다(사용자 요청 2026-07-29: 도서관 대출 화면 사진). 라벨이 좁으면
  /// 사용자가 그것을 찍어도 되는지 모른다.
  static const aiSourceEvent = '행사 일정표';
  static const aiSourceTask = '내 할 일·기한';

  /// 아무것도 못 뽑았을 때. **종류에 맞춰 말한다** — 업무 쪽지로 넣었는데
  /// `행사를 찾지 못했어요`가 뜨면 잘못 넣은 줄 안다.
  static String aiParseEmptyFor(EntryKind kind) =>
      '붙여넣은 내용에서 ${kind.label}을(를) 찾지 못했어요. AI 응답(JSON)을 복사했는지 확인해 주세요';

  /// JSON은 읽혔지만 **모든 항목이 형식 오류**일 때.
  ///
  /// [aiParseEmptyFor]와 구분한다 — 이쪽은 "AI가 답을 주긴 했는데 우리가 못
  /// 받았다"이고, 사용자가 할 일이 다르다(다시 복사할 게 아니라 다시 뽑아야 한다).
  static String aiParseAllInvalid(int n) =>
      '$n건을 받았지만 날짜 형식이 맞지 않아 읽지 못했어요. AI에 다시 요청해 주세요';

  static String aiPreviewDup(int n) => '중복 $n건 제외';

  /// 형식이 어긋나 버린 건수. **보여주지 않으면 조용히 사라진다** —
  /// 파서는 세고 있었지만 아무도 읽지 않아, AI가 5줄을 줘도 3건만 보이고
  /// 나머지가 어디 갔는지 알 길이 없었다. 손글씨 목록에서는 모든 줄이
  /// 살아남아야 해서 더 문제다.
  static String aiPreviewSkipped(int n) => '형식 오류 $n건 건너뜀';

  /// 붙여넣기 결과 한 줄 — **미리보기 시트가 하던 말을 그대로 진다**
  /// (인식 건수 · 중복 제외 · 형식 오류 건너뜀).
  ///
  /// 시트를 없앤 뒤로 이 문구가 "붙여넣기가 됐다"는 **유일한 신호**다. 그래서
  /// [created]가 0이어도 조용히 지나가지 않는다 — 전부 중복이면 목록이 그대로라
  /// 화면만 봐서는 버튼이 눌린 건지 알 수 없다.
  ///
  /// 종류 이름은 **[EntryKind.label]에서 온다.** 여기 다시 박으면 용어가 바뀔 때
  /// 배지·칩만 따라가고 이 문구만 옛 이름으로 남는다(일괄 확정 pill이 그랬다).
  static String aiRegisterSummary(
    EntryKind kind, {
    required int created,
    required int dup,
    required int skipped,
  }) => [
    if (created > 0) '${kind.label} $created건을 검토 목록에 넣었어요' else '새로 넣을 게 없어요',
    if (dup > 0) aiPreviewDup(dup),
    if (skipped > 0) aiPreviewSkipped(skipped),
  ].join(' · ');

  // 입력 탭 히어로 — 사진 AI가 주 경로, 작년 업무 CSV는 보조 한 줄
  /// **`행사`를 떼었다.** 쪽지의 마감 기한도 이 경로로 들어오므로(업무로 저장된다)
  /// 제목이 행사라고 못박으면 사용자가 쪽지를 넣을 수 있다는 것을 모른다.
  static const heroTitle = '사진으로 넣기';
  static const heroSubtitle = '일정표나 할 일이 적힌 걸 찍어 AI에게 맡기세요';
  static const heroStepCopy = '① 프롬프트';
  static const heroStepAway = 'AI 앱';
  static const heroStepPaste = '② 붙여넣기';
  static const heroCsvLink = '작년 업무 가져오기 (에듀파인 CSV)';

  // 에듀파인에서 CSV 받고 가져오는 방법 가이드 (Import Initial 뷰 내 접힘 섹션)
  static const edufineGuideTitle = '에듀파인에서 CSV로 일정 받고 공직플랜에 적용하는 방법';

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
