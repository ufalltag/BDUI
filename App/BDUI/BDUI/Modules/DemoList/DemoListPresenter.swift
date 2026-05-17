import Foundation

// MARK: - Model

struct DemoScreenItem {
    let id: String
    let title: String
    let subtitle: String
}

// MARK: - View contract

protocol DemoListViewProtocol: AnyObject {
    func display(_ items: [DemoScreenItem])
}

// MARK: - Presenter contract

protocol DemoListPresenterProtocol: PresenterProtocol {
    var itemCount: Int { get }
    func item(at index: Int) -> DemoScreenItem
    func didSelectItem(at index: Int)
}

// MARK: - Presenter implementation

final class DemoListPresenter: DemoListPresenterProtocol {

    weak var view: DemoListViewProtocol?
    private weak var router: DemoListRouterProtocol?

    private let items: [DemoScreenItem] = [
        DemoScreenItem(
            id: "profile",
            title: "Profile",
            subtitle: "Avatar, stats, bio — demonstrates static layout reuse"
        ),
        DemoScreenItem(
            id: "home",
            title: "Home",
            subtitle: "Story carousel + feed — heavy static, light dynamic"
        ),
        DemoScreenItem(
            id: "settings",
            title: "Settings",
            subtitle: "Toggles and rows — almost all static structure"
        ),
        DemoScreenItem(
            id: "catalog",
            title: "Catalog",
            subtitle: "Product grid with dynamic prices and filters"
        ),
        DemoScreenItem(
            id: "product",
            title: "Product Detail",
            subtitle: "Gallery, variants, reviews — live stock info"
        )
    ]

    init(view: DemoListViewProtocol, router: DemoListRouterProtocol) {
        self.view   = view
        self.router = router
    }

    // MARK: - PresenterProtocol

    func viewDidLoad() {
        view?.display(items)
    }

    // MARK: - DemoListPresenterProtocol

    var itemCount: Int { items.count }

    func item(at index: Int) -> DemoScreenItem { items[index] }

    func didSelectItem(at index: Int) {
        router?.showBDUIScreen(screenId: items[index].id)
    }
}
