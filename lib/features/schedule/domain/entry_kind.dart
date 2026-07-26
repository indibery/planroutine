import '../../../core/constants/app_strings.dart';

/// 업무 / 행사 구분.
///
/// 두 종류는 성격이 다르다. **업무**는 내가 처리해야 하는 일이라 완료 개념이 핵심이고,
/// 오늘 탭에 떠서 체크·도장 대상이 된다. **행사**는 학교에서 열리는 일이라
/// 참고 정보이고 캘린더에만 보인다 — "운동회를 완료했다"는 어색하기 때문이다.
///
/// 입력 경로가 종류를 결정한다:
///   - 작년 CSV(생산문서등록대장) → 업무
///   - 월간 일정표 사진(AI 변환) → 행사
enum EntryKind {
  /// 내가 처리할 일. 오늘 탭에 뜬다.
  task('task', ScheduleStrings.kindTask),

  /// 학교에서 열리는 일. 캘린더에만 보인다.
  event('event', ScheduleStrings.kindEvent);

  const EntryKind(this.dbValue, this.label);

  /// DB(`schedules.kind` / `calendar_events.kind`)에 저장되는 값.
  /// **표시 이름이 바뀌어도 이 값은 그대로다** — 용어 변경은 표시 계층만이다.
  final String dbValue;

  /// 화면에 쓰는 이름. 배지·필터 칩·요약 줄이 **모두 이 하나**를 쓴다.
  ///
  /// 예전에는 짧은 `label`(`일정`)과 긴 `filterLabel`(`학교일정`)로 나뉘어 있었다 —
  /// 짧은 쪽이 우산말 `일정`과 겹쳐 업무와의 대비가 약했기 때문이다. `행사`는 2글자로도
  /// 충분히 강해 그 분리가 필요 없어졌다.
  final String label;

  /// 오늘 탭에 나타나는 종류인지. 업무만 뜬다.
  bool get showsInToday => this == EntryKind.task;

  /// DB 값 → enum. 모르는 값·null은 업무로 폴백한다.
  ///
  /// v7 마이그레이션이 `DEFAULT 'task'`를 주므로 실무상 null은 없지만,
  /// 컬럼이 없던 시절 백업을 복원하는 경로가 있어 방어한다.
  static EntryKind fromValue(String? value) {
    return EntryKind.values.firstWhere(
      (k) => k.dbValue == value,
      orElse: () => EntryKind.task,
    );
  }
}
