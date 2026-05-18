import XCTest
import BDUIClient
@testable import BDUI

// MARK: - Mock screen loader

private final class MockScreenLoader: BDUIScreenLoaderProtocol {
    var result: Result<ScreenData, Error> = .failure(BDUIError.serverError(statusCode: 503))
    var lastForceRefresh = false

    func load(screenId: String, forceRefresh: Bool) async throws -> ScreenData {
        lastForceRefresh = forceRefresh
        return try result.get()
    }
}

// MARK: - Mock view

@MainActor
private final class MockBDUIScreenView: BDUIScreenViewProtocol {
    var showLoadingCount   = 0
    var hideLoadingCount   = 0
    var buildLayoutCount   = 0
    var applyDynamicCount  = 0
    var showErrorCalled    = false
    var lastAppliedDynamic: JSONValue?
    var lastCacheStatus: (isHit: Bool, cacheKey: String)?

    var onHideLoading: (() -> Void)?
    var onBuildLayout: (() -> Void)?
    var onApplyDynamic: (() -> Void)?
    var onShowError: (() -> Void)?

    func setTitle(_ title: String) {}
    func showLoading()  { showLoadingCount += 1 }
    func hideLoading()  { hideLoadingCount += 1; onHideLoading?() }
    func buildLayout(from screen: StaticScreen) { buildLayoutCount += 1; onBuildLayout?() }
    func applyDynamic(_ dynamic: JSONValue) {
        applyDynamicCount += 1
        lastAppliedDynamic = dynamic
        onApplyDynamic?()
    }
    func updateCacheStatus(isHit: Bool, cacheKey: String) {
        lastCacheStatus = (isHit, cacheKey)
    }
    func showError(_ message: String, onRetry: @escaping () -> Void) {
        showErrorCalled = true
        onShowError?()
    }
}

// MARK: - Mock router

private final class MockBDUIScreenRouter: BDUIScreenRouterProtocol {
    var didPop = false
    func pop() { didPop = true }
}

// MARK: - Helpers

private func makeScreenData(
    cacheKey: String = "abc123",
    username: String = "Tagir"
) -> ScreenData {
    let json = """
    {
      "protocol_version": 1,
      "ui": {
        "static": {
          "screen_id": "profile",
          "layout": "ProfileLayout",
          "navigation": { "tab_bar": false, "back_button": true, "title": "Profile" },
          "components": []
        },
        "dynamic": { "username": "\(username)" }
      },
      "cache_key": "\(cacheKey)"
    }
    """.data(using: .utf8)!
    let response = try! JSONDecoder().decode(BDUIServerResponse.self, from: json)
    return ScreenData(
        staticScreen: response.ui.staticScreen!,
        dynamic: response.ui.dynamic,
        cacheKey: cacheKey
    )
}

// MARK: - BDUIScreenPresenter Tests

@MainActor
final class BDUIScreenPresenterTests: XCTestCase {

    private var mockLoader: MockScreenLoader!
    private var mockView: MockBDUIScreenView!
    private var mockRouter: MockBDUIScreenRouter!
    private var presenter: BDUIScreenPresenter!

    override func setUp() {
        super.setUp()
        mockLoader = MockScreenLoader()
        mockView   = MockBDUIScreenView()
        mockRouter = MockBDUIScreenRouter()
        presenter  = BDUIScreenPresenter(
            view: mockView,
            screenId: "profile",
            loader: mockLoader,
            router: mockRouter
        )
    }

    // MARK: Loading state

    func test_viewDidLoad_showsLoadingImmediately() {
        mockLoader.result = .success(makeScreenData())
        presenter.viewDidLoad()
        XCTAssertEqual(mockView.showLoadingCount, 1)
    }

    func test_successfulLoad_hidesLoading() {
        let exp = expectation(description: "hideLoading called")
        mockView.onHideLoading = { exp.fulfill() }
        mockLoader.result = .success(makeScreenData())

        presenter.viewDidLoad()
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(mockView.hideLoadingCount, 1)
    }

    // MARK: Layout building

    func test_firstLoad_buildsLayout() {
        let exp = expectation(description: "buildLayout called")
        mockView.onBuildLayout = { exp.fulfill() }
        mockLoader.result = .success(makeScreenData())

        presenter.viewDidLoad()
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(mockView.buildLayoutCount, 1)
    }

    func test_firstLoad_appliesDynamic() {
        let exp = expectation(description: "applyDynamic called")
        mockView.onApplyDynamic = { exp.fulfill() }
        mockLoader.result = .success(makeScreenData(username: "Tagir"))

        presenter.viewDidLoad()
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(mockView.lastAppliedDynamic, .object(["username": .string("Tagir")]))
    }

    // MARK: Cache status

    func test_firstLoad_reportsCacheStatus_notHit() {
        let exp = expectation(description: "applyDynamic called")
        mockView.onApplyDynamic = { exp.fulfill() }
        mockLoader.result = .success(makeScreenData())

        presenter.viewDidLoad()
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(mockView.lastCacheStatus?.isHit, false)
    }

    func test_secondLoad_sameCacheKey_reportsCacheHit() {
        let data = makeScreenData(cacheKey: "abc123")

        // First load
        let exp1 = expectation(description: "first applyDynamic")
        mockView.onApplyDynamic = { exp1.fulfill() }
        mockLoader.result = .success(data)
        presenter.viewDidLoad()
        wait(for: [exp1], timeout: 2.0)

        // Reset callback, then second load with same key
        let exp2 = expectation(description: "second applyDynamic")
        mockView.onApplyDynamic = { exp2.fulfill() }
        presenter.didTapRetry()
        wait(for: [exp2], timeout: 2.0)

        XCTAssertEqual(mockView.lastCacheStatus?.isHit, true)
    }

    func test_secondLoad_differentCacheKey_reportsNotHit() {
        // First load with key "v1"
        let exp1 = expectation(description: "first load")
        mockView.onApplyDynamic = { exp1.fulfill() }
        mockLoader.result = .success(makeScreenData(cacheKey: "v1"))
        presenter.viewDidLoad()
        wait(for: [exp1], timeout: 2.0)

        // Second load with key "v2" (cache miss / new layout)
        let exp2 = expectation(description: "second load")
        mockView.onApplyDynamic = { exp2.fulfill() }
        mockLoader.result = .success(makeScreenData(cacheKey: "v2"))
        presenter.didTapRetry()
        wait(for: [exp2], timeout: 2.0)

        XCTAssertEqual(mockView.lastCacheStatus?.isHit, false)
    }

    // MARK: Layout rebuild logic

    func test_sameCacheKey_doesNotRebuildLayout() {
        let data = makeScreenData(cacheKey: "abc123")

        // First load
        let exp1 = expectation(description: "first layout")
        mockView.onBuildLayout = { exp1.fulfill() }
        mockLoader.result = .success(data)
        presenter.viewDidLoad()
        wait(for: [exp1], timeout: 2.0)

        // Second load with same key
        let exp2 = expectation(description: "second applyDynamic")
        mockView.onApplyDynamic = { exp2.fulfill() }
        presenter.didTapRetry()
        wait(for: [exp2], timeout: 2.0)

        XCTAssertEqual(mockView.buildLayoutCount, 1)
    }

    func test_differentCacheKey_rebuildsLayout() {
        // First load
        let exp1 = expectation(description: "first layout")
        mockView.onBuildLayout = { exp1.fulfill() }
        mockLoader.result = .success(makeScreenData(cacheKey: "v1"))
        presenter.viewDidLoad()
        wait(for: [exp1], timeout: 2.0)

        // Second load with different key
        let exp2 = expectation(description: "second layout")
        mockView.onBuildLayout = { exp2.fulfill() }
        mockLoader.result = .success(makeScreenData(cacheKey: "v2"))
        presenter.didTapRetry()
        wait(for: [exp2], timeout: 2.0)

        XCTAssertEqual(mockView.buildLayoutCount, 2)
    }

    // MARK: Error handling

    func test_errorLoad_hidesLoading() {
        let exp = expectation(description: "hideLoading after error")
        mockView.onHideLoading = { exp.fulfill() }
        mockLoader.result = .failure(BDUIError.serverError(statusCode: 500))

        presenter.viewDidLoad()
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(mockView.hideLoadingCount, 1)
    }

    func test_errorLoad_showsError() {
        let exp = expectation(description: "showError called")
        mockView.onShowError = { exp.fulfill() }
        mockLoader.result = .failure(BDUIError.serverError(statusCode: 500))

        presenter.viewDidLoad()
        wait(for: [exp], timeout: 2.0)

        XCTAssertTrue(mockView.showErrorCalled)
    }

    func test_errorLoad_doesNotBuildLayout() {
        let exp = expectation(description: "showError called")
        mockView.onShowError = { exp.fulfill() }
        mockLoader.result = .failure(BDUIError.serverError(statusCode: 500))

        presenter.viewDidLoad()
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(mockView.buildLayoutCount, 0)
    }

    // MARK: Force refresh

    func test_forceRefresh_passesForceRefreshTrue() {
        let exp = expectation(description: "applyDynamic called")
        mockView.onApplyDynamic = { exp.fulfill() }
        mockLoader.result = .success(makeScreenData())

        presenter.forceRefresh()
        wait(for: [exp], timeout: 2.0)

        XCTAssertTrue(mockLoader.lastForceRefresh)
    }

    func test_viewDidLoad_doesNotPassForceRefresh() {
        let exp = expectation(description: "applyDynamic called")
        mockView.onApplyDynamic = { exp.fulfill() }
        mockLoader.result = .success(makeScreenData())

        presenter.viewDidLoad()
        wait(for: [exp], timeout: 2.0)

        XCTAssertFalse(mockLoader.lastForceRefresh)
    }
}
