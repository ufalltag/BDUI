import UIKit
import BDUIClient

/// Root coordinator. Creates the navigation stack, owns shared dependencies,
/// and assembles every module on demand.
///
/// `SceneDelegate` creates one `AppRouter` and sets `navigationController`
/// as the window's root — that is the only place this type is referenced concretely.
final class AppRouter: RouterProtocol {

    // MARK: - RouterProtocol

    let navigationController: UINavigationController

    // MARK: - Shared dependencies (created once, injected into modules)

    private let screenLoader: BDUIScreenLoader

    // MARK: - Init

    init() {
        let client   = BDUIClient(baseURL: URL(string: "http://localhost:3000")!)
        screenLoader = BDUIScreenLoader(client: client)

        navigationController = UINavigationController()

        let rootVC = DemoListAssembly.assemble(router: self)
        navigationController.setViewControllers([rootVC], animated: false)
    }
}

// MARK: - DemoListRouterProtocol

extension AppRouter: DemoListRouterProtocol {
    func showBDUIScreen(screenId: String) {
        let vc = BDUIScreenAssembly.assemble(
            screenId: screenId,
            loader: screenLoader,
            router: self
        )
        push(vc)
    }
}

// MARK: - BDUIScreenRouterProtocol

extension AppRouter: BDUIScreenRouterProtocol {
    func pop() {
        navigationController.popViewController(animated: true)
    }

    func showScreen(screenId: String) {
        let vc = BDUIScreenAssembly.assemble(
            screenId: screenId,
            loader: screenLoader,
            router: self
        )
        push(vc)
    }
}
