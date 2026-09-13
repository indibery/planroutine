/// Swift(App Intents)와 Dart가 공유하는 채널 계약.
///
/// **이 저장소에서 같은 사실이 두 곳에 적히는 유일한 자리다.** Swift에는
/// Dart 상수를 import할 방법이 없어 문자열을 다시 쓸 수밖에 없다 —
/// `test/core/app_intents/app_intents_wiring_test.dart`가 두 파일을 읽어
/// 양방향으로 대조한다. 이름을 바꿀 때는 세 곳(여기·Swift·가드)이 함께 간다.
abstract final class AppIntentsContract {
  const AppIntentsContract._();

  static const channelName = 'planroutine/app_intents';

  /// Swift → Dart
  static const methodRegister = 'registerSchedules';
  static const methodQuery = 'querySchedules';

  /// Dart → Swift. 핸들러 등록이 끝났음을 알린다.
  /// **이 신호가 없으면 Swift는 인텐트를 처리하지 않고 기다린다** —
  /// 앱이 꺼진 상태에서 기동과 인텐트 실행의 순서가 보장되지 않기 때문이다.
  static const methodReady = 'ready';

  static const argText = 'text';
  static const argKind = 'kind';
  static const argRange = 'range';
}
