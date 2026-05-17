import UIKit

/// Wires the DemoList MVP triad.
/// The only file in this module that knows all three concrete types.
enum DemoListAssembly {
    static func assemble(router: DemoListRouterProtocol) -> UIViewController {
        let view      = DemoListViewController()
        let presenter = DemoListPresenter(view: view, router: router)
        view.presenter = presenter
        return view
    }
}
