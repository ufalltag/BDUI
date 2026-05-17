import UIKit
import BDUIClient

/// Wires the BDUIScreen MVP triad.
/// The only file in this module that knows all three concrete types.
enum BDUIScreenAssembly {
    static func assemble(
        screenId: String,
        loader: BDUIScreenLoader,
        router: BDUIScreenRouterProtocol
    ) -> UIViewController {
        let view      = BDUIScreenViewController()
        let presenter = BDUIScreenPresenter(
            view: view,
            screenId: screenId,
            loader: loader,
            router: router
        )
        view.presenter = presenter
        return view
    }
}
