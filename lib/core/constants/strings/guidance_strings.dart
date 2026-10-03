/// 지도 기록(선택 탭) 문자열. 이후 Task가 이 클래스에 상수를 더한다.
class GuidanceStrings {
  GuidanceStrings._();

  // 등록부·탭
  static const title = '지도 기록';
  static const tabLabel = '지도 기록';
  static const eyebrow = 'RECORD';
  static const moduleDescription =
      '학교 단계의 생활지도·교육활동 침해를 잠금 안에 기록해 둡니다';

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
  static const peopleTitle = '명단 관리';
  static const trashTitle = '삭제한 기록';
  static const kindAll = '전체';
  static const personAll = '사람: 전체';
  static String personLabel(String name) => '사람: $name';
  static const personPickerTitle = '사람으로 찾기';
  static const personPickerEmpty = '기록에 등장한 사람이 아직 없습니다';
  static const empty = '아직 기록이 없습니다';
  static const emptyScope =
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
  static const addPerson = '사람 추가';
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

  // 관련인 고르기
  static const pickerTitle = '관련인 추가';
  static const pickerQueryHint = '이름';
  static String outsideRoster(String name) => '‘$name’ 명단 밖 이름으로 넣기';
  static const outsideMemoHint = '소속·관계 (예: 5반, 민준 어머니)';
  static const addToRoster = '명단에도 추가';
  static const pickerConfirm = '넣기';

  // 기록 보기
  static const edit = '수정';
  static const delete = '삭제';
  static const more = '더 보기';
  static const labelOccurredShort = '사건';
  static const labelCreatedShort = '기록';
  static String revisionLink(int times, String last) => '수정 $times회 · 마지막 $last';
  static const labelAttachments = '첨부';
  static const deleteTitle = '이 기록을 삭제할까요?';
  static const deleteMessage = '삭제한 기록으로 옮겨집니다. 자동으로 지워지지 않으며, 거기서 되살릴 수 있습니다.';
  static const outsideRosterBadge = '명단 밖';

  // 첨부
  static const play = '재생';
  static const pause = '멈춤';
  static const attachmentInfo = '첨부 정보';
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
  static const historyIntro = '저장할 때마다 그때 내용이 수정 버전으로 남습니다. 이전 버전은 고치거나 지울 수 없어요.';

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
  static const importHintCallRecording =
      '아이폰 통화 녹음(iOS 18.1 이상)은 메모 앱에 저장됩니다. 메모에서 공유 › 파일에 저장한 뒤 가져오세요.';
  static const removeAttachmentTitle = '첨부를 삭제할까요?';
  static const removeAttachmentMessage = '목록에서는 사라지지만 파일과 수정 이력은 남습니다.';
  static const removeAttachmentConfirm = '삭제';

  // 녹음 화면
  static const recordingLive = '녹음 중';
  static const recordingStop = '녹음 멈추기';
  static const recordingStopHint = '멈추면 이 기록에 붙어요';
  static const recordingLegal =
      '대화에 직접 참여하는 경우에만 녹음하세요. 자리를 비운 사이의 녹음은 불법이 될 수 있습니다.';
  static const recordingNotice = '가능하면 녹음한다고 먼저 알려 주세요.';
  static const recordingScreenOn = '녹음하는 동안 화면이 꺼지지 않아요 · 앱을 떠나면 여기까지 저장돼요';
  static const micDenied = '마이크 권한이 꺼져 있어요';
  static const micDeniedBody = '설정에서 공직플랜의 마이크를 켜면 녹음할 수 있습니다.';
  static const openSettings = '설정 열기';
  static const recordingStartFailed = '녹음을 시작하지 못했어요. 다른 앱이 마이크를 쓰고 있는지 확인해 주세요.';
  static const recordingClose = '닫기';

  // 붙이지 못한 녹음
  static String unattachedRecording(int n) => '붙이지 못한 녹음 $n개';
  static const retryAttach = '다시 붙이기';
  static const attachFailedKept = '녹음은 보관했어요. 아래 다시 붙이기를 눌러 주세요.';

  // 명단 관리
  static String studentsHeader(int n) => '학생 · $n명';
  static const othersHeader = '보호자 · 교직원 · 기타';
  static String archivedHeader(int n) => '보관된 사람 · $n명';
  static String recordCount(int n) => '기록 $n';
  static const pasteTitle = '여러 명 붙여넣기';
  static const pasteHint = '한 줄에 한 명씩. 앞의 번호는 지워집니다.';
  static String pastePreview(int n) => '$n명을 학생으로 넣습니다';
  static const pasteConfirm = '넣기';
  static String pasteDone(int n) => '$n명을 넣었어요';
  static const personAddTitle = '사람 추가';
  static const personEditTitle = '사람 수정';
  static const personName = '이름';
  static const personMemo = '소속·관계';
  static const archive = '보관';
  static const unarchive = '되살리기';
  static const archiveNote = '보관해도 옛 기록의 이름은 그대로 남습니다.';
  static const actionFailed = '처리하지 못했어요. 다시 눌러 주세요.';

  // 삭제한 기록
  static const trashIntro =
      '자동으로 지워지지 않습니다. 영구 삭제하면 처음 작성부터 모든 수정 버전과 녹음·사진이 함께 지워지고 되돌릴 수 없습니다.';
  static const trashEmpty = '삭제한 기록이 없습니다';
  static String deletedAt(String when) => '삭제 $when';
  static const restore = '되살리기';
  static const purge = '영구 삭제';
  static const purgeTitle = '영구 삭제할까요?';
  static const purgeMessage = '이 기록의 저장된 내용과 수정 이력, 첨부 파일이 모두 지워집니다. 되돌릴 수 없습니다.';
}
