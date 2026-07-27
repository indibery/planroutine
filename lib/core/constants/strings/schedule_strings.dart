/// 일정 검토/확정 UI 문자열.
class ScheduleStrings {
  ScheduleStrings._();

  /// 탭 화면 제목. 이 탭은 업무와 행사를 **둘 다** 넣으므로 그냥 '입력'이다.
  static const title = '입력';

  /// 검토 섹션 헤더 — 입력 영역 아래, 대기가 있을 때만 크게 나온다.
  static const reviewSection = '검토';
  static const confirm = '확정';
  static const delete = '삭제';

  // 일괄 확정 pill — 스코프+건수 동적 라벨 (confirmAllPillLabel이 조합)
  static String confirmPending(int count) => '대기 $count건 확정';
  static String confirmPendingIn(String category, int count) =>
      '$category 대기 $count건 확정';
  static const pending = '검토 대기';
  static const confirmed = '확정됨';
  static const all = '전체';
  static const empty = '등록된 일정이 없습니다';
  static const emptyFiltered = '해당 조건의 일정이 없습니다';

  // 대기 중심 뷰 — 상태 칩 건수 / 확정 요약 / 완료 상태
  static String chipPending(int n) => '검토 대기 $n';
  static String chipConfirmed(int n) => '확정됨 $n';
  static String doneSummary(int n) => '확정 $n건은 캘린더에 반영됨';
  static const reviewDoneTitle = '검토가 끝났어요';

  // 대기가 없을 때의 최소 요약 — 검토는 검토할 때만 크게 나온다.
  static const reviewIdle = '검토 대기 없음';
  static String confirmedTotal(int n) => '확정 $n건';
  static String reviewDoneBody(int n) =>
      '확정한 $n건은 캘린더에 반영됐습니다.\n새 일정은 가져오기에서 추가하세요.';
  static String viewConfirmed(int n) => '확정됨 $n건 보기';
  static const goImport = '일정 가져오기';

  /// 펼친 상태의 필터 줄 라벨. 접히면 이 자리에 현재 필터 요약이 들어간다
  /// (펼친 상태에서 요약을 그대로 두면 아래 칩과 같은 말을 반복한다).
  static const filter = '필터';

  // 종류 (업무 / 행사)
  static const kindTask = '업무';
  static const kindEvent = '행사';

  /// 일괄 등록 pill — 종류별로 나눠 성격이 다른 것이 섞여 확정되지 않게 한다.
  ///
  /// 종류 이름은 **인자로 받는다**([EntryKind.label]). 여기에 `업무`/`행사`를 다시
  /// 박으면 다음 용어 변경 때 배지·필터 칩만 따라가고 이 pill만 옛 이름으로 남는다 —
  /// 직전 main이 정확히 그 상태였다(`kindEvent`는 `학교일정`, pill은 `일괄 일정 등록`).
  static String bulkRegister(String kindLabel, int n) => '일괄 $kindLabel 등록 $n건';

  static const bulkConfirmTitle = '일괄 확정';
  static String bulkConfirmMessageFor(String scope, int count) =>
      '$scope 검토 대기 $count건을 확정하고 캘린더에 반영합니다.';

  // 일괄 삭제 pill (확정 대칭) — 남은 검토 대기를 한 번에 휴지통으로
  static String deletePending(int count) => '대기 $count건 삭제';
  static const bulkDeleteTitle = '검토 대기 삭제';
  static String bulkDeleteMessageFor(String scope, int count) =>
      '$scope 검토 대기 $count건을 휴지통으로 보냅니다.\n'
      '30일 후 자동 삭제되며, 그 전엔 설정 > 휴지통에서 복구할 수 있어요.';
  static String bulkDeletedSnack(int count) => '$count건을 휴지통으로 옮겼어요';

  // 스와이프 삭제 Undo
  static const deletedSnack = '일정을 삭제했어요';
  static const undoAction = '실행취소';

  // 수정 시트
  static const editTitle = '일정 수정';
  static const titleLabel = '제목';
  static const descriptionHint = '설명 (선택사항)';
  static const dateLabel = '일정 날짜';

  // 스와이프 힌트
  static const slideHintConfirm = '오른쪽으로 밀기 — 확정되어 캘린더 적용';
  static const slideHintDelete = '왼쪽으로 밀기 — 삭제';
}
