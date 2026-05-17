import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var router: AppRouter?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let router = AppRouter()
        self.router = router

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = router.navigationController
        window.makeKeyAndVisible()
        self.window = window
    }
}
