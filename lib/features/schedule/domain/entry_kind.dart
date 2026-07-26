import '../../../core/constants/app_strings.dart';

/// 업무 / 학교일정 구분.
///
/// 두 종류는 성격이 다르다. **업무**는 내가 처리해야 하는 일이라 완료 개념이 핵심이고,
/// 오늘 탭에 떠서 체크·도장 대상이 된다. **학교일정**은 학교에서 일어나는 일이라
/// 참고 정보이고 캘린더에만 보인다 — "운동회를 완료했다"는 어색하기 때문이다.
///
/// 입력 경로가 종류를 결정한다:
///   - 작년 CSV(생산문서등록대장) → 업무
///   - 월간 일정표 사진(AI 변환) → 학교일정
enum EntryKind {
  /// 내가 처리할 일. 오늘 탭에 뜬다.
  task('task', '업무', ScheduleStrings.kindTask),

  /// 학교에서 일어나는 일. 캘린더에만 보인다.
  event('event', '일정', ScheduleStrings.kindEvent);

  const EntryKind(this.dbValue, this.label, this.filterLabel);

  /// DB(`schedules.kind` / `calendar_events.kind`)에 저장되는 값.
  final String dbValue;

  /// 배지·pill에 쓰는 짧은 라벨. 행마다 반복되므로 4글자 이내.
  final String label;

  /// 필터 칩·요약 줄에 쓰는 라벨. 한 번만 나오므로 뜻을 다 적는다
  /// (`일정`만 쓰면 업무와의 대비가 흐려진다).
  final String filterLabel;

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
