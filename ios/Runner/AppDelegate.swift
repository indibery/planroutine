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
  }
}
