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
}
