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

  /// Dart가 준비되기 전에 인텐트가 도착했을 때. **조용히 빈 결과를 주지 않는다** —
  /// 사용자가 "등록됐다"고 믿는 것이 가장 나쁜 결과다.
  static const notReady = '앱이 아직 준비되지 않았어요. 잠시 후 다시 시도해 주세요';
}
