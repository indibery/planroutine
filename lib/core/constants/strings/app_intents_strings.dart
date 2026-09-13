/// 단축어(App Intents)가 사용자에게 돌려주는 문구.
///
/// 화면이 아니라 **단축어 결과 칸과 시리 대사**로 읽히므로 짧고 평서문이다.
abstract final class AppIntentsStrings {
  const AppIntentsStrings._();

  static const digestEmptyToday = '오늘은 등록된 일정이 없어요';
  static const digestEmptyWeek = '이번 주는 등록된 일정이 없어요';
  static const digestEmptyMonth = '이번 달은 등록된 일정이 없어요';

  static const digestHeaderToday = '오늘 일정';
  static const digestHeaderWeek = '이번 주 일정';
  static const digestHeaderMonth = '이번 달 일정';

  /// 완료한 항목 뒤에 붙는 표시.
  static const doneMark = '완료';

  /// 단축어 등록 결과. **도착지가 캘린더라고 말한다.**
  ///
  /// 화면 경로(`ImportStrings.aiRegisterSummary`)는 `검토 목록`이라고 말하는데,
  /// 두 경로의 도착지가 실제로 다르기 때문이다 — 단축어는 검토 관문을 건너뛴다.
  /// **문구와 도착지는 양방향으로 묶여 있고 가드가 검사한다**: 여기서 `검토`라고
  /// 하면 사용자가 입력 탭을 열어보고 아무것도 없어 실패로 읽는다.
  static String registerSummary(
    String kindLabel, {
    required int created,
    required int dup,
    required int invalid,
  }) => [
    if (created > 0) '$kindLabel $created건을 캘린더에 넣었어요' else '새로 넣을 게 없어요',
    if (dup > 0) '중복 $dup건 제외',
    if (invalid > 0) '형식이 어긋난 $invalid건 제외',
  ].join(' · ');

  /// Dart가 준비되기 전에 인텐트가 도착했을 때. **조용히 빈 결과를 주지 않는다** —
  /// 사용자가 "등록됐다"고 믿는 것이 가장 나쁜 결과다.
  static const notReady = '앱이 아직 준비되지 않았어요. 잠시 후 다시 시도해 주세요';
}
