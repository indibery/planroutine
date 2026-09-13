import Flutter
import UIKit

/// 다른 앱(카카오톡/메일/파일 앱)이 CSV 파일을 "공직플랜으로 열기"로 넘길 때
/// iOS는 앱 번들로 file:// URL을 보내며 `application(_:open:options:)`를 호출한다.
/// 그 경로를 method channel(`planroutine/shared_file`)로 Flutter에 전달한다.
///
/// 타이밍 — Flutter 엔진이 준비되기 전에 URL이 도착한 cold-start 경우, 경로를
/// `pendingPath`에 버퍼해뒀다가 Flutter 측이 `getPending`으로 꺼내간다. 이미
/// 엔진이 준비된 running 경우는 즉시 `onFileShared`로 push.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static var pendingPath: String?
  static var sharedChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if url.isFileURL {
      let path = url.path
      AppDelegate.pendingPath = path
      AppDelegate.sharedChannel?.invokeMethod("onFileShared", arguments: path)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlanRoutineSharedFile")
    if let messenger = registrar?.messenger() {
      let channel = FlutterMethodChannel(
        name: "planroutine/shared_file",
        binaryMessenger: messenger
      )
      AppDelegate.sharedChannel = channel
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getPending":
          let path = AppDelegate.pendingPath
          AppDelegate.pendingPath = nil
          result(path)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // 단축어(App Intents)가 Dart를 부를 통로를 잡아 둔다.
    //
    // **이 자리여야 한다** — `didFinishLaunchingWithOptions` 시점에는
    // `window?.rootViewController`가 아직 nil이고(실측), registrar가 주는
    // messenger는 플러그인 등록 직후부터 유효하다.
    if #available(iOS 16.0, *) {
      let intentRegistrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "PlanRoutineIntents")
      if let intentMessenger = intentRegistrar?.messenger() {
        PlanRoutineBridge.messenger = intentMessenger
        let intentChannel = FlutterMethodChannel(
          name: PlanRoutineChannel.name,
          binaryMessenger: intentMessenger
        )
        intentChannel.setMethodCallHandler { call, result in
          // Dart가 핸들러 등록을 마쳤다는 신호. 이것을 받기 전에는
          // 인텐트가 기다린다 — 기동과 인텐트 실행의 순서가 보장되지 않는다.
          if call.method == PlanRoutineChannel.ready {
            PlanRoutineBridge.markReady()
            result(nil)
          } else {
            result(FlutterMethodNotImplemented)
          }
        }
      }
    }
  }
}
