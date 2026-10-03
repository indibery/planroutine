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
  static const lockedBody = '다른 탭으로 옮기거나 앱을 떠나면 다시 잠깁니다.';
  static const unlock = '잠금 해제';
  static const noCredentialsTitle = '기기 암호가 설정되어 있지 않아요';
  static const noCredentialsBody =
      '기기 암호나 Face ID·지문을 설정해야 기록이 보호됩니다. 설정하지 않아도 쓸 수는 있습니다.';
  static const openWithoutLock = '잠금 없이 열기';

  // 기록 쓰기
  static const editNewTitle = '새 기록';
  static const editTitle = '기록 고치기';
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
  static const discardMessage = '고친 내용이 사라집니다. 이미 저장된 판은 그대로 남습니다.';
  static const discardConfirm = '나가기';

  // 관련인 고르기
  static const pickerTitle = '관련인 추가';
  static const pickerQueryHint = '이름';
  static String outsideRoster(String name) => '‘$name’ 명단 밖 이름으로 넣기';
  static const outsideMemoHint = '소속·관계 (예: 5반, 민준 어머니)';
  static const addToRoster = '명단에도 추가';
  static const pickerConfirm = '넣기';
}
