import Foundation
import BDUIClient

// MARK: - View contract

protocol BDUIScreenViewProtocol: AnyObject {
    func setTitle(_ title: String)
    func showLoading()
    func hideLoading()
    func showError(_ message: String, onRetry: @escaping () -> Void)
    func buildLayout(from screen: StaticScreen)
    func applyDynamic(_ dynamic: JSONValue)
    func updateCacheStatus(isHit: Bool, cacheKey: String)
    func showMessage(_ message: String)
}

// MARK: - Presenter contract

protocol BDUIScreenPresenterProtocol: PresenterProtocol {
    func didTapRetry()
    func forceRefresh()
    func handle(action: BDUIAction, from componentId: String)
}

// MARK: - Presenter implementation

/// Owns all state and logic for a BDUI screen:
/// - triggers the load
/// - decides when to rebuild the full layout vs only refresh dynamic data
/// - reports cache-hit / full-response status to the View
final class BDUIScreenPresenter: BDUIScreenPresenterProtocol {

    weak var view: BDUIScreenViewProtocol?
    private weak var router: BDUIScreenRouterProtocol?

    private let screenId: String
    private let loader: any BDUIScreenLoaderProtocol
    private var currentCacheKey: String?

    init(
        view: BDUIScreenViewProtocol,
        screenId: String,
        loader: any BDUIScreenLoaderProtocol,
        router: BDUIScreenRouterProtocol
    ) {
        self.view     = view
        self.screenId = screenId
        self.loader   = loader
        self.router   = router
    }

    // MARK: - PresenterProtocol

    func viewDidLoad() {
        loadScreen()
    }

    // MARK: - BDUIScreenPresenterProtocol

    func didTapRetry() {
        loadScreen()
    }

    /// Bypasses the local cache and fetches a fresh full response from the server.
    func forceRefresh() {
        loadScreen(forceRefresh: true)
    }

    /// Routes an action fired by a component view.
    /// Selection (filter/sort/tab) is handled locally by the views themselves,
    /// so here it's just acknowledged — no server round-trip in this mode.
    func handle(action: BDUIAction, from componentId: String) {
        switch action.type {
        case "navigate":
            if let screen = action.string("screen") {
                router?.showScreen(screenId: screen)
            }
        case "refresh":
            forceRefresh()
        case "reload":
            // Re-fetch the same screen for a different content variant (e.g. a
            // catalog category). Static layout is unchanged, so only the dynamic
            // part is reloaded — server returns a CacheHit with the new data.
            loadScreen(category: action.string("category"))
        case "select":
            // Local-only: visual selection already applied by the component.
            break
        default:
            view?.showMessage(action.displayName)
        }
    }

    // MARK: - Private

    private func loadScreen(forceRefresh: Bool = false, category: String? = nil) {
        view?.showLoading()
        Task {
            do {
                let data = try await loader.load(screenId: screenId, forceRefresh: forceRefresh, category: category)
                await MainActor.run { [weak self] in self?.apply(data) }
            } catch {
                await MainActor.run { [weak self] in
                    self?.view?.hideLoading()
                    self?.view?.showError(error.localizedDescription) { [weak self] in
                        self?.loadScreen()
                    }
                }
            }
        }
    }

    @MainActor
    private func apply(_ data: ScreenData) {
        view?.hideLoading()

        let isFirstLoad = currentCacheKey == nil
        let isCacheHit  = !isFirstLoad && currentCacheKey == data.cacheKey

        // Rebuild the full layout only when the static structure changes.
        if isFirstLoad || currentCacheKey != data.cacheKey {
            view?.setTitle(data.staticScreen.navigation.title)
            view?.buildLayout(from: data.staticScreen)
            currentCacheKey = data.cacheKey
        }

        view?.applyDynamic(data.dynamic)
        view?.updateCacheStatus(isHit: isCacheHit, cacheKey: data.cacheKey)
    }
}
