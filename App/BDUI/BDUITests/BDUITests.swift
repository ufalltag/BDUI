import XCTest
@testable import BDUI

// MARK: - DemoListPresenter Tests

@MainActor
final class DemoListPresenterTests: XCTestCase {

    private var mockView: MockDemoListView!
    private var mockRouter: MockDemoListRouter!
    private var presenter: DemoListPresenter!

    override func setUp() {
        super.setUp()
        mockView   = MockDemoListView()
        mockRouter = MockDemoListRouter()
        presenter  = DemoListPresenter(view: mockView, router: mockRouter)
    }

    // MARK: viewDidLoad

    func test_viewDidLoad_callsDisplayOnView() {
        presenter.viewDidLoad()
        XCTAssertTrue(mockView.displayCalled)
    }

    func test_viewDidLoad_displaysFiveItems() {
        presenter.viewDidLoad()
        XCTAssertEqual(mockView.displayedItems?.count, 5)
    }

    func test_viewDidLoad_firstItemIsProfile() {
        presenter.viewDidLoad()
        XCTAssertEqual(mockView.displayedItems?.first?.id, "profile")
    }

    func test_viewDidLoad_lastItemIsProduct() {
        presenter.viewDidLoad()
        XCTAssertEqual(mockView.displayedItems?.last?.id, "product")
    }

    // MARK: itemCount / item(at:)

    func test_itemCount_isFive() {
        XCTAssertEqual(presenter.itemCount, 5)
    }

    func test_itemAtZero_isProfile() {
        XCTAssertEqual(presenter.item(at: 0).id, "profile")
    }

    func test_itemAtOne_isHome() {
        XCTAssertEqual(presenter.item(at: 1).id, "home")
    }

    func test_itemAtTwo_isSettings() {
        XCTAssertEqual(presenter.item(at: 2).id, "settings")
    }

    func test_itemAtThree_isCatalog() {
        XCTAssertEqual(presenter.item(at: 3).id, "catalog")
    }

    func test_itemAtFour_isProduct() {
        XCTAssertEqual(presenter.item(at: 4).id, "product")
    }

    // MARK: didSelectItem

    func test_didSelectItem_callsRouter() {
        presenter.didSelectItem(at: 0)
        XCTAssertNotNil(mockRouter.navigatedScreenId)
    }

    func test_didSelectItem_profileIndex_navigatesToProfile() {
        presenter.didSelectItem(at: 0)
        XCTAssertEqual(mockRouter.navigatedScreenId, "profile")
    }

    func test_didSelectItem_catalogIndex_navigatesToCatalog() {
        presenter.didSelectItem(at: 3)
        XCTAssertEqual(mockRouter.navigatedScreenId, "catalog")
    }

    func test_didSelectItem_eachItem_matchesDisplayedItem() {
        presenter.viewDidLoad()
        guard let items = mockView.displayedItems else { return XCTFail("No items displayed") }
        for (index, item) in items.enumerated() {
            presenter.didSelectItem(at: index)
            XCTAssertEqual(mockRouter.navigatedScreenId, item.id,
                           "Index \(index): expected \(item.id)")
        }
    }
}

// MARK: - Mocks for DemoList

@MainActor
private final class MockDemoListView: DemoListViewProtocol {
    var displayCalled = false
    var displayedItems: [DemoScreenItem]?

    func display(_ items: [DemoScreenItem]) {
        displayCalled = true
        displayedItems = items
    }
}

@MainActor
private final class MockDemoListRouter: DemoListRouterProtocol {
    var navigatedScreenId: String?

    func showBDUIScreen(screenId: String) {
        navigatedScreenId = screenId
    }
}
