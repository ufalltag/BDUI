import UIKit
import BDUIClient

/// Pure view — renders what the Presenter instructs.
/// Contains zero business logic and no networking.
final class BDUIScreenViewController: UIViewController {

    // MARK: - MVP

    var presenter: BDUIScreenPresenterProtocol!

    // MARK: - UI

    private let renderer          = BDUIRenderer()
    private let scrollView        = UIScrollView()
    private let contentView       = UIView()
    private let cacheBanner       = CacheBannerView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        renderer.actionDispatcher = self
        setupLayout()
        presenter.viewDidLoad()
    }

    // MARK: - Actions

    @objc private func handleRefresh() {
        scrollView.refreshControl?.endRefreshing()
        presenter.forceRefresh()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        cacheBanner.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl

        view.addSubviews(cacheBanner, scrollView, activityIndicator)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            cacheBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            cacheBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cacheBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: cacheBanner.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// MARK: - BDUIScreenViewProtocol

extension BDUIScreenViewController: BDUIScreenViewProtocol {

    func setTitle(_ title: String) {
        self.title = title
    }

    func showLoading() {
        activityIndicator.startAnimating()
    }

    func hideLoading() {
        activityIndicator.stopAnimating()
    }

    func showError(_ message: String, onRetry: @escaping () -> Void) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in onRetry() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func buildLayout(from screen: StaticScreen) {
        renderer.buildLayout(from: screen, in: contentView)
    }

    func applyDynamic(_ dynamic: JSONValue) {
        renderer.applyDynamic(dynamic)
    }

    func updateCacheStatus(isHit: Bool, cacheKey: String) {
        cacheBanner.update(isHit: isHit, cacheKey: cacheKey)
    }

    func showMessage(_ message: String) {
        let alert = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - BDUIActionDispatching

extension BDUIScreenViewController: BDUIActionDispatching {
    func dispatch(_ action: BDUIAction, from componentId: String) {
        // Search is a view-layer concern (local filtering) — keep it in the renderer.
        if action.type == "search" {
            renderer.applyFilter(target: action.string("target"), query: action.string("query") ?? "")
            return
        }
        presenter.handle(action: action, from: componentId)
    }
}

// MARK: - Cache status banner

private final class CacheBannerView: UIView {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(isHit: Bool, cacheKey: String) {
        let short = String(cacheKey.prefix(8))
        if isHit {
            label.text       = "Cache HIT — key: \(short)… (static skipped)"
            backgroundColor  = UIColor.systemGreen.withAlphaComponent(0.15)
        } else {
            label.text       = "Full response — key: \(short)…"
            backgroundColor  = UIColor.systemBlue.withAlphaComponent(0.15)
        }
    }

    private func setup() {
        label.font          = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 1
        addSubview(label)
        label.pinToEdges(of: self, insets: UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8))
        constrainSize(height: 32)
    }
}
