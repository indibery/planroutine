/// 지도 기록(선택 탭) 문자열. 이후 Task가 이 클래스에 상수를 더한다.
class GuidanceStrings {
  GuidanceStrings._();

  // 등록부·탭
  static const title = '지도 기록';
  static const tabLabel = '지도 기록';
  static const eyebrow = 'RECORD';
  static const moduleDescription = '학교 단계의 생활지도·교육활동 침해를 잠금 안에 기록해 둡니다';

  // 사람 구분
  static const roleStudent = '학생';
  static const roleGuardian = '보호자';
  static const roleStaff = '교직원';
  static const roleOther = '기타';

  // 기록 구분
  static const kindGuidance = '생활지도';
  static const kindInfringement = '교육활동 침해';

  // 진행 상태
  static const statusOpen = '진행 중';
  static const statusClosedAtSchool = '학교에서 마무리';
  static const statusTransferred = '교육청 이관';
  static const statusClosedShort = '마무리';
  static const statusTransferredShort = '이관';

  // 사건 시각
  static const precisionExact = '정확히';
  static const precisionDate = '날짜만';
  static const precisionApprox = '대략';
  static const occurredUnknown = '시각 모름';

  // 첨부
  static const attachmentAudio = '녹음';
  static const attachmentImage = '사진';
  static const sourceRecorded = '앱에서 녹음';
  static const sourceImported = '가져옴';

  // 바뀐 칸 이름(수정 이력)
  static const fieldKind = '구분';
  static const fieldStatus = '진행 상태';
  static const fieldOccurred = '사건 시각';
  static const fieldTitle = '제목';
  static const fieldPlace = '장소';
  static const fieldParticipants = '관련인';
  static const fieldFacts = '경과';
  static const fieldQuotes = '들은 말';
  static const fieldActions = '판단·조치';

  // 전체 초기화 경고
  static String resetWarning(int records, int attachments) =>
      '지도 기록 $records건과 첨부 $attachments개도 지워집니다.';

  /// 기록이 0건이어도 명단은 지워진다 — 따로 말한다.
  static String resetPeopleWarning(int people) => '지도 기록 명단 $people명도 지워집니다.';

  // 목록
  static const newRecord = '새 기록';
  static const trashTitle = '삭제한 기록';

  /// 목록 오른쪽 위 삭제한 기록 버튼의 작은 글자 — 휴지통 아이콘만으로는 "지운다"로 읽힐 수 있다.
  static const trashShortcut = '복구';

  /// 목록의 녹음 버튼 이름 — 누르면 새 기록을 만들고 곧바로 녹음을 시작한다.
  static const newRecordByRecording = '녹음으로 새 기록';

  /// 녹음 버튼으로 시작한 새 기록의 미리 넣는 제목 — 녹음만 하고 바로 저장해도 구별된다.
  /// [n]은 그날 만든 기록 순번(1부터).
  static String autoTitle(DateTime day, int n) =>
      '${day.month}월 ${day.day}일 지도 기록 $n';
  static const kindAll = '전체';
  static const personAll = '사람: 전체';
  static String personLabel(String name) => '사람: $name';
  static const personPickerTitle = '사람으로 찾기';
  static const personPickerEmpty = '기록에 등장한 사람이 아직 없습니다';
  static const empty = '아직 기록이 없습니다';
  static const emptyHint = '+ 를 눌러 첫 기록을 남겨 보세요';

  /// 새 기록 화면 `구분` 아래 범위 안내. 예전에는 목록 빈 상태에 있었다(2026-10-04 옮김).
  static const scopeNote =
      '학교 단계의 생활지도·교육활동 침해를 남기는 곳입니다. 교육청으로 이관된 뒤의 조사는 전담조사관이 맡습니다.';
  static const noMatch = '조건에 맞는 기록이 없습니다';
  static String revisedTimes(int n) => '수정 $n회';

  // 잠금
  static const unlockReason = '지도 기록을 열려면 본인 확인이 필요합니다';
  static const lockedTitle = '지도 기록은 잠겨 있어요';
  static const lockedBody = '지도 기록을 떠난 지 15분이 지나면 다시 잠깁니다.';
  static const unlock = '잠금 해제';
  static const noCredentialsTitle = '기기 암호가 설정되어 있지 않아요';
  static const noCredentialsBody =
      '기기 암호나 Face ID·지문을 설정해야 기록이 보호됩니다. 설정하지 않아도 쓸 수는 있습니다.';
  static const openWithoutLock = '잠금 없이 열기';

  // 기록 쓰기
  static const editNewTitle = '새 기록';
  static const editTitle = '기록 수정';
  static const save = '저장';
  static const cancel = '취소';
  static const untitled = '제목 없음';
  static const titleRequired = '제목을 적어 주세요';
  static const labelKind = '구분';
  static const labelStatus = '진행 상태';
  static const labelOccurred = '사건 시각';
  static const labelCreated = '기록 시각';
  static const createdOnSave = '저장할 때 자동으로 남아요';
  static const labelTitle = '제목';
  static const labelPlace = '장소';
  static const labelParticipants = '관련인';
  static const labelFacts = '경과';
  static const labelQuotes = '들은 말';
  static const labelActions = '판단·조치';
  static const approxHint = '예: 3월 초~여름방학 전';
  static const pickDate = '날짜';
  static const pickTime = '시각';
  static const notPicked = '고르기';
  static const participantsInputHint = '이름을 쉼표로 구분해 여러 명 쓸 수 있어요';
  static const suggestionHint = '한 번 쓴 이름이 추천으로 떠요.';
  static const participantsHint =
      '가해·피해를 나누어 적지 않아요. 판단이 나오기 전의 기록이 결론처럼 읽힐 수 있어서입니다. 필요하면 경과에 사실대로 적어 주세요.';
  static const quotesHint = '누가 무엇이라고 말했는지 들은 그대로 적어 주세요.';
  static const actionsHint = '어떻게 지도했는지, 보호자 연락·학교 보고·이관을 언제 했는지 적어 주세요.';
  static const discardTitle = '저장하지 않고 나갈까요?';
  static const discardMessage = '고친 내용이 사라집니다. 이미 저장된 내용은 그대로 남습니다.';

  /// 붙이지 못한 녹음이 남은 채 나가려 할 때 — 나가면 그 녹음을 이 화면에서 다시 붙일 길이 없다.
  static String discardUnattachedMessage(int n) =>
      '붙이지 못한 녹음 $n개가 있어요. 나가면 이 화면에서 다시 붙일 수 없습니다.';
  static const discardConfirm = '나가기';
  static const saveFailed = '저장하지 못했어요. 다시 눌러 주세요.';

  // 기록 보기
  static const edit = '수정';
  static const delete = '삭제';
  static const labelOccurredShort = '사건';
  static const labelCreatedShort = '기록';
  static String revisionLink(int times, String last) =>
      '수정 $times회 · 마지막 $last';
  static const labelAttachments = '첨부';
  static const deleteTitle = '이 기록을 삭제할까요?';
  static const deleteMessage = '삭제한 기록으로 옮겨집니다. 자동으로 지워지지 않으며, 거기서 되살릴 수 있습니다.';

  // 첨부
  static const play = '재생';
  static const pause = '멈춤';
  static const attachmentInfo = '첨부 정보';
  static const openImage = '사진 보기';
  static const attachmentMissing = '파일을 찾을 수 없어요';
  static const removeAttachment = '첨부 삭제';
  static const infoSource = '출처';
  static const infoOriginalName = '원래 이름';
  static const infoSize = '크기';
  static const infoCaptured = '녹음 시작';
  static const infoAttached = '붙인 시각';
  static const infoHash = 'SHA-256';
  static const infoHashNote = '파일이 바뀌지 않았음을 확인할 때 쓰는 값입니다.';
  static String durationLabel(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static String sizeLabel(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB'
      : '${(bytes / 1024).ceil()}KB';

  // 수정 이력
  static const historyTitle = '수정 이력';
  static const historyIntro =
      '저장할 때마다 그때 내용이 수정 버전으로 남습니다. 이전 버전은 고치거나 지울 수 없어요.';

  /// 화면에서는 `판`이라는 말을 쓰지 않는다(사용자 결정 2026-10-03) — 판 1은 `처음 작성`,
  /// 판 n은 `수정 버전 n-1`. 목록의 `수정 N회`와 번호가 맞는다.
  static String revisionTitle(int no) => no == 1 ? '처음 작성' : '수정 버전 ${no - 1}';
  static const revisionCurrent = '현재';
  static String changedLabel(String fields) => '바뀐 칸: $fields';
  static const attachmentLog = '첨부 기록';
  static String attachedLog(String what) => '$what 붙임';
  static String removedLog(String what) => '$what 삭제';

  // 첨부 넣기
  static const record = '녹음하기';
  static const importAudio = '녹음 파일 가져오기';
  static const importImage = '사진 가져오기';
  static const importHintSchoolPhone = '학부모 통화는 학교 전화 사용이 원칙입니다.';
  static const removeAttachmentTitle = '첨부를 삭제할까요?';
  static const removeAttachmentMessage = '목록에서는 사라지지만 파일과 수정 이력은 남습니다.';
  static const removeAttachmentConfirm = '삭제';

  // 녹음 화면
  static const recordingLive = '녹음 중';
  static const recordingStop = '녹음 멈추기';
  static const recordingStopHint = '멈추면 이 기록에 붙어요';
  // 한글은 글자 단위로 줄이 바뀌므로 녹음 화면 안내는 한 줄에 들어가게 짧게 쓴다(320pt 가드).
  static const recordingLegal = '직접 참여한 대화만 녹음하세요.';
  static const recordingScreenOn = '녹음 중에는 화면이 켜져 있어요.';
  static const recordingSavesOnLeave = '앱을 나가면 그때까지 저장돼요.';
  static const micDenied = '마이크 권한이 꺼져 있어요';
  static const micDeniedBody = '설정에서 공직플랜의 마이크를 켜면 녹음할 수 있습니다.';
  static const openSettings = '설정 열기';
  static const recordingStartFailed =
      '녹음을 시작하지 못했어요. 다른 앱이 마이크를 쓰고 있는지 확인해 주세요.';
  static const recordingClose = '닫기';

  // 붙이지 못한 녹음
  static String unattachedRecording(int n) => '붙이지 못한 녹음 $n개';
  static const retryAttach = '다시 붙이기';
  static const attachFailedKept = '녹음은 보관했어요. 아래 다시 붙이기를 눌러 주세요.';

  // 이름 추천 지우기 등 명단 동작
  static const actionFailed = '처리하지 못했어요. 다시 눌러 주세요.';

  // 삭제한 기록
  static const trashIntro =
      '자동으로 지워지지 않습니다. 영구 삭제하면 처음 작성부터 모든 수정 버전과 녹음·사진이 함께 지워지고, 이 기록에만 나온 이름 추천도 함께 지워집니다. 되돌릴 수 없습니다.';
  static const trashEmpty = '삭제한 기록이 없습니다';
  static String deletedAt(String when) => '삭제 $when';
  static const restore = '되살리기';
  static const purge = '영구 삭제';
  static const purgeTitle = '영구 삭제할까요?';
  static const purgeMessage =
      '이 기록의 저장된 내용과 수정 이력, 첨부 파일이 모두 지워집니다. 이 기록에만 나온 이름 추천도 함께 지워집니다. 되돌릴 수 없습니다.';

  // 글로 보기(참고용 전사)
  static const transcribe = '글로 보기';
  static const transcribeTag = '참고용';
  static const transcriptTitle = '글로 보기';
  static const transcriptCopyAll = '전체 복사';
  static const transcriptCopy = '복사';
  static const transcriptCopied = '복사했어요';
  static const transcriptNotice = '작은 목소리는 빠지거나 틀릴 수 있어요. 기록에 옮기기 전에 들어 보세요.';
  static const transcriptProgress = '받아 적는 중…';
  static const transcriptProgressNotice = '이 화면을 닫으면 멈춰요. 녹음은 휴대폰 밖으로 나가지 않아요.';
  static const transcriptPreparing = '한국어 음성 인식 모델을 준비하는 중이에요. 처음 한 번 Apple에서 내려받아요.';
  static String transcriptGap(String from, int seconds) => '$from부터 $seconds초 동안 글이 없어요 · 들어 보기';
  static const transcriptEmpty = '받아 적을 말소리를 찾지 못했어요';
  static const transcriptModelFailed = '처음 한 번은 인터넷 연결이 필요해요';
  static const transcriptFailed = '글로 바꾸지 못했어요';
  static const transcriptRetry = '다시 시도';
  static String transcriptPlayFrom(String time) => '$time부터 재생';

  // 내보내기
  static const export = '내보내기';
  static const exportBundle = '제출용 묶음(ZIP)';
  static String exportBundleSubtitle(int audio, int image) {
    final parts = [
      if (audio > 0) '$attachmentAudio $audio개',
      if (image > 0) '$attachmentImage $image개',
    ];
    return parts.isEmpty ? 'PDF' : 'PDF + ${parts.join(' · ')} 원본';
  }

  static const exportAudioOnly = '녹음만';
  static const exportAudioOnlySubtitle = '원본 파일 그대로';
  static const exportAudioOnlyExcluded = '녹음만 보낼 때는 빠져요';
  static const exportAudioSaveOneOnly = '여러 개는 공유로 보내 주세요';
  static const exportPdfOnly = 'PDF만';
  static const exportPdfOnlySubtitle = '인쇄·내부 보고용';
  static const exportNotice = '학생 이름과 기록 내용이 담깁니다. 받는 사람을 확인하세요.';
  static const exportShare = '공유';
  static const exportSaveToDevice = '기기에 저장';
  static const exportSaved = '다운로드 폴더 등 고른 곳에 저장했어요';
  static const exportShared = '공유했어요';
  static const exportFailed = '내보내지 못했어요. 다시 눌러 주세요.';
  static const exportPcGuideTitle = 'PC로 옮기는 방법';

  /// 두 기기 모두 메일 → 카카오톡 → 드라이브 순서(사용자 결정 2026-10-04 — 실제로 많이 쓰는 경로가 앞).
  /// 케이블은 안드로이드 마지막에만 있다. 아이폰은 Windows가 사진 폴더만 보여 줘 앱 파일을 꺼낼 수 없다.
  static const exportPcGuideIos = [
    '메일 — 공유에서 메일 앱을 골라 나에게 보내고, PC에서 웹메일로 받아요.',
    '카카오톡 — 공유에서 카카오톡 나와의 채팅으로 보내고, PC 카카오톡에서 받아요.',
    '드라이브 — 공유에서 "파일에 저장"(iCloud Drive)이나 구글 드라이브로 보내고, PC 브라우저에서 받아요.',
  ];
  static const exportPcGuideAndroid = [
    '메일 — 공유에서 메일 앱을 골라 나에게 보내고, PC에서 웹메일로 받아요.',
    '카카오톡 — 공유에서 카카오톡 나와의 채팅으로 보내고, PC 카카오톡에서 받아요.',
    '드라이브 — 공유에서 구글 드라이브로 보내고, PC 브라우저에서 받아요.',
    'USB 케이블 — 기기에 저장에서 "다운로드"를 고르고, PC에 꽂아 복사해요.',
  ];

  // 내보내기 PDF
  static const pdfTitle = '지도 기록';
  static const pdfLastEdited = '마지막 수정';
  static String pdfEdits(int edits) => edits == 0 ? '수정 없음' : '수정 $edits회';
  static const pdfAttachments = '첨부';
  static const pdfOriginalsInZip = '원본은 제출용 묶음(ZIP)에 같은 이름으로 들어 있습니다.';
  static const pdfOriginalsHint = "원본은 앱에서 '제출용 묶음(ZIP)'으로 내보낼 수 있습니다.";
  static const pdfCertutil = 'Windows에서 대조: certutil -hashfile 파일이름 SHA256';
  static String pdfAppendixTitle(int n, String no) => '붙임 $n (첨부 $no)';
  static const pdfPhotoNote = 'PDF에 넣은 사진은 축소본입니다. 해시는 원본 기준입니다.';
  static const pdfPhotoUnsupported =
      '이 사진은 PDF에 넣을 수 없는 형식입니다. 원본은 제출용 묶음(ZIP)에 있습니다.';
  static String pdfFooter(String stamp, int page, int pages) =>
      '공직플랜에서 $stamp에 만듦 · $page/$pages쪽';
}
