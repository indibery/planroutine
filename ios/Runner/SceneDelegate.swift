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

  // MARK: - 지도 기록 앱 전환기 가림막
  //
  // Flutter 잠금 덮개는 inactive 콜백 한 프레임 뒤에 그려진다(런타임 확인 2026-10-03). iOS가
  // 앱 전환기 스냅샷을 그보다 먼저 찍으면 기록 내용이 카드에 남을 수 있어, 비활성이 되는 순간
  // 네이티브에서 불투명한 뷰로 덮는다. 지도 기록이 화면에 있을 때만(AppDelegate.secureContent).
  //
  // 가림막은 창이 아니라 루트 뷰 컨트롤러의 뷰 위에 얹는다 — 그 위에 모달로 뜬 사진·파일 고르기
  // 창은 가리지 않는다(고르기 창이 앱을 비활성으로 만들어도 고르기는 계속된다).

  private var privacyCover: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    guard AppDelegate.secureContent, privacyCover == nil,
          let host = window?.rootViewController?.view else { return }
    let cover = UIView(frame: host.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // 앱 배경색(AppColors.background) — 다크 #0A1628 / 라이트 #F6F8FB. 앱 안 테마 선택은
    // 네이티브가 모르므로 기기 밝기를 따른다.
    cover.backgroundColor = UIColor { trait in
      trait.userInterfaceStyle == .dark
        ? UIColor(red: 0x0A / 255.0, green: 0x16 / 255.0, blue: 0x28 / 255.0, alpha: 1)
        : UIColor(red: 0xF6 / 255.0, green: 0xF8 / 255.0, blue: 0xFB / 255.0, alpha: 1)
    }
    let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
    lock.tintColor = .secondaryLabel
    lock.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40)
    lock.translatesAutoresizingMaskIntoConstraints = false
    cover.addSubview(lock)
    NSLayoutConstraint.activate([
      lock.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      lock.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
    ])
    host.addSubview(cover)
    privacyCover = cover
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyCover?.removeFromSuperview()
    privacyCover = nil
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
