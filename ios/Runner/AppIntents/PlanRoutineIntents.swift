import AppIntents
import Flutter
import UIKit

// MARK: - 채널 계약

/// ⚠️ **Dart의 `AppIntentsContract`와 같은 값을 다시 쓴다.**
/// Swift에서 Dart 상수를 import할 방법이 없다.
/// `test/core/app_intents/app_intents_wiring_test.dart`가 두 파일을 대조한다.
enum PlanRoutineChannel {
  static let name = "planroutine/app_intents"
  static let register = "registerSchedules"
  static let query = "querySchedules"
  static let ready = "ready"
  static let argText = "text"
  static let argKind = "kind"
  static let argRange = "range"
}

// MARK: - Dart 다리

/// Dart로 가는 통로와 준비 상태를 들고 있는 단일 창구.
///
/// **`window.rootViewController`를 쓰지 않는다** — `didFinishLaunching` 시점에
/// 아직 nil이다(실측). registrar가 주는 messenger는 그 시점에 이미 유효하다.
@available(iOS 16.0, *)
enum PlanRoutineBridge {
  /// `AppDelegate`가 채워 준다.
  static var messenger: FlutterBinaryMessenger?

  /// Dart가 핸들러 등록을 마치면 true가 된다.
  private static var isReady = false
  private static let lock = NSLock()

  static func markReady() {
    lock.lock()
    isReady = true
    lock.unlock()
  }

  private static var readyNow: Bool {
    lock.lock()
    defer { lock.unlock() }
    return isReady
  }

  /// Dart 준비를 기다린다. 이미 준비됐으면 즉시 통과한다.
  ///
  /// **상한은 5초다.** 실측에서 기동부터 Dart 준비까지 약 1초였고, 인텐트가
  /// 시스템에서 받는 시간이 약 30초이므로 그 안에 넉넉히 든다.
  ///
  /// 폴링으로 기다린다. continuation을 타임아웃과 경쟁시키면 타임아웃이 이겼을 때
  /// 깨어나지 못한 continuation이 남는다 — `withCheckedContinuation`은 취소를
  /// 인식하지 못하기 때문이다.
  static func waitUntilReady(timeout: TimeInterval = 5) async -> Bool {
    if readyNow { return true }
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
      if readyNow { return true }
    }
    return readyNow
  }

  /// Dart를 부르고 문자열 응답을 받는다.
  @MainActor
  static func call(_ method: String, arguments: [String: Any]) async -> String? {
    guard let messenger else { return nil }
    let channel = FlutterMethodChannel(
      name: PlanRoutineChannel.name, binaryMessenger: messenger)
    return await withCheckedContinuation { cont in
      var resumed = false
      channel.invokeMethod(method, arguments: arguments) { result in
        guard !resumed else { return }
        resumed = true
        cont.resume(returning: result as? String)
      }
    }
  }
}

// MARK: - 선택지

@available(iOS 16.0, *)
enum ScheduleKindOption: String, AppEnum {
  case event
  case task

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "종류")
  static var caseDisplayRepresentations: [ScheduleKindOption: DisplayRepresentation] = [
    .event: "행사",
    .task: "업무",
  ]
}

@available(iOS 16.0, *)
enum RangeOption: String, AppEnum {
  case today
  case thisWeek = "this_week"
  case thisMonth = "this_month"

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "기간")
  static var caseDisplayRepresentations: [RangeOption: DisplayRepresentation] = [
    .today: "오늘",
    .thisWeek: "이번 주",
    .thisMonth: "이번 달",
  ]
}

// MARK: - 인텐트

/// AI 앱이 뽑은 일정 텍스트를 검토 대기로 넣는다.
///
/// **`openAppWhenRun`을 쓰지 않는다** — 명시하지 않으면 기본값 `false`로 빌드돼
/// 앱이 전면에 뜨지 않는다(빌드 산출물로 확인). `true`로 바꾸면 이 기능의
/// 전제가 통째로 무너진다.
@available(iOS 16.0, *)
struct RegisterSchedulesIntent: AppIntent {
  static var title: LocalizedStringResource = "일정 등록"
  static var description = IntentDescription("AI가 뽑은 일정 텍스트를 검토 목록에 넣습니다")

  @Parameter(title: "일정 텍스트")
  var text: String

  @Parameter(title: "종류", default: .event)
  var kind: ScheduleKindOption

  static var parameterSummary: some ParameterSummary {
    Summary("\(\.$text)을(를) \(\.$kind)(으)로 등록")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard await PlanRoutineBridge.waitUntilReady() else {
      return .result(dialog: "앱이 아직 준비되지 않았어요. 잠시 후 다시 시도해 주세요")
    }
    let reply = await PlanRoutineBridge.call(
      PlanRoutineChannel.register,
      arguments: [
        PlanRoutineChannel.argText: text,
        PlanRoutineChannel.argKind: kind.rawValue,
      ]
    )
    return .result(dialog: IntentDialog(stringLiteral: reply ?? "등록하지 못했어요"))
  }
}

/// 기간을 받아 일정 목록을 텍스트로 돌려준다.
@available(iOS 16.0, *)
struct QuerySchedulesIntent: AppIntent {
  static var title: LocalizedStringResource = "일정 조회"
  static var description = IntentDescription("기간을 골라 등록된 일정을 가져옵니다")

  @Parameter(title: "기간", default: .today)
  var range: RangeOption

  static var parameterSummary: some ParameterSummary {
    Summary("\(\.$range) 일정 가져오기")
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard await PlanRoutineBridge.waitUntilReady() else {
      let message = "앱이 아직 준비되지 않았어요. 잠시 후 다시 시도해 주세요"
      return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
    let reply =
      await PlanRoutineBridge.call(
        PlanRoutineChannel.query,
        arguments: [PlanRoutineChannel.argRange: range.rawValue]
      ) ?? "일정을 가져오지 못했어요"
    return .result(value: reply, dialog: IntentDialog(stringLiteral: reply))
  }
}

@available(iOS 16.0, *)
struct PlanRoutineShortcuts: AppShortcutsProvider {
  /// ⚠️ **모든 문구에 앱 이름(`applicationName`)이 들어가야 한다.** 애플의 제약이고
  /// 빠지면 컴파일조차 안 된다. 그래서 사용자가 "일정 보기"라고만 말하면 시리는
  /// 그것을 **자기 캘린더 명령으로 해석한다** — 앱에서 바꿀 수 없다.
  ///
  /// 문구를 여럿 두는 이유는 사람이 한 가지로만 말하지 않기 때문이다(애플 권장 3~5개).
  /// 하나만 두면 그 표현을 정확히 맞혀야 한다.
  ///
  /// ⚠️ **문구는 정적 리터럴이어야 한다** — 문자열을 만들어 넣을 수 없다.
  @AppShortcutsBuilder
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: QuerySchedulesIntent(),
      phrases: [
        "\(.applicationName) 일정 보기",
        "\(.applicationName) 일정 알려줘",
        "\(.applicationName) 일정 확인",
        "\(.applicationName)에서 일정 보기",
      ],
      shortTitle: "일정 조회",
      systemImageName: "calendar"
    )
    AppShortcut(
      intent: RegisterSchedulesIntent(),
      phrases: [
        "\(.applicationName)에 일정 등록",
        "\(.applicationName)에 일정 추가",
        "\(.applicationName)에 일정 넣기",
        "\(.applicationName) 일정 등록",
      ],
      shortTitle: "일정 등록",
      systemImageName: "square.and.pencil"
    )
  }
}
