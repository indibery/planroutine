/// 공통 문자열 + 도메인별 Strings 클래스 barrel export.
///
/// 도메인별 문자열은 `strings/` 하위의 각 클래스에서 관리한다:
/// - SettingsStrings, NotificationStrings, GoogleStrings
/// - ImportStrings, ScheduleStrings, CalendarStrings, TrashStrings
///
/// 이 파일 하나만 import 하면 모든 Strings 클래스를 쓸 수 있다.
library;

export 'strings/calendar_integration_strings.dart';
export 'strings/calendar_strings.dart';
export 'strings/google_strings.dart';
export 'strings/import_strings.dart';
export 'strings/notification_strings.dart';
export 'strings/schedule_strings.dart';
export 'strings/settings_strings.dart';
export 'strings/trash_strings.dart';

/// 도메인에 귀속되지 않는 공통 문자열.
class AppStrings {
  AppStrings._();

  // 앱 기본
  static const appName = '공직플랜';

  // 탭/네비게이션
  static const tabCalendar = '캘린더';
  static const tabSchedule = '일정';

  // 공통 액션
  static const save = '저장';
  static const cancel = '취소';
  static const delete = '삭제';
  static const retry = '다시 시도';
  static const loading = '로딩 중...';
  static const error = '오류가 발생했습니다';

  // 연도 표기 접미사 (ImportSummaryCard, ScheduleScreen 월별 헤더 등)
  static const compareYearFormat = '년';

  // 카테고리 매칭 리터럴 (색상 결정 등)
  static const categoryDailyOps = '일과운영관리';
}
