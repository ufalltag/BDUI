import UIKit

/// Base navigation contract. Owns the navigation stack.
/// Default implementations via extension so concrete routers don't repeat boilerplate.
protocol RouterProtocol: AnyObject {
    var navigationController: UINavigationController { get }
}

extension RouterProtocol {
    func push(_ viewController: UIViewController, animated: Bool = true) {
        navigationController.pushViewController(viewController, animated: animated)
    }

    func pop(animated: Bool = true) {
        navigationController.popViewController(animated: animated)
    }
}

// MARK: - Module-specific router contracts (Interface Segregation Principle)
// Each module gets only the navigation actions it actually needs.

/// Navigation contract visible to the DemoList module.
protocol DemoListRouterProtocol: AnyObject {
    func showBDUIScreen(screenId: String)
}

/// Navigation contract visible to the BDUIScreen module.
protocol BDUIScreenRouterProtocol: AnyObject {
    func pop()
    /// Pushes another BDUI screen — used by `navigate` actions.
    func showScreen(screenId: String)
}
