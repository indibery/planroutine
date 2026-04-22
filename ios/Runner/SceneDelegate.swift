import Flutter
import UIKit

/// iOS 13+ scene-based lifecycle. FlutterSceneDelegate는 기본적으로 scene
/// URL 이벤트(`openURLContexts`, `willConnectTo` 시 launch URL)를 AppDelegate의
/// `application(_:open:options:)`로 자동 포워딩하지 않는다. receive_sharing_intent
/// 같은 플러그인은 AppDelegate hook에서 URL을 받도록 설계돼 있어, scene 이벤트를
/// 명시적으로 AppDelegate로 넘겨줘야 공유된 파일 경로가 Flutter 측 스트림에
/// 도달한다.
class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Cold start — 외부 앱이 공유로 런칭한 경우 URL이 connectionOptions에 담긴다.
    for urlContext in connectionOptions.urlContexts {
      forwardToAppDelegate(url: urlContext.url, options: urlContext.options)
    }
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    // 앱 실행 중 공유받은 경우.
    for urlContext in URLContexts {
      forwardToAppDelegate(url: urlContext.url, options: urlContext.options)
    }
  }

  private func forwardToAppDelegate(
    url: URL,
    options sceneOptions: UIScene.OpenURLOptions
  ) {
    var appOptions: [UIApplication.OpenURLOptionsKey: Any] = [:]
    if let source = sceneOptions.sourceApplication {
      appOptions[.sourceApplication] = source
    }
    if let annotation = sceneOptions.annotation {
      appOptions[.annotation] = annotation
    }
    appOptions[.openInPlace] = sceneOptions.openInPlace
    _ = UIApplication.shared.delegate?.application?(
      UIApplication.shared,
      open: url,
      options: appOptions
    )
  }
}
