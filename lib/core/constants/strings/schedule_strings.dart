/// 일정 검토/확정 UI 문자열.
class ScheduleStrings {
  ScheduleStrings._();

  static const title = '일정 검토';
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
  static String reviewDoneBody(int n) =>
      '확정한 $n건은 캘린더에 반영됐습니다.\n새 일정은 가져오기에서 추가하세요.';
  static String viewConfirmed(int n) => '확정됨 $n건 보기';
  static const goImport = '일정 가져오기';

  static const bulkConfirmTitle = '일괄 확정';
  static String bulkConfirmMessageFor(String scope, int count) =>
      '$scope 검토 대기 $count건을 확정하고 캘린더에 반영합니다.';

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
