import UIKit

/// Pure view — renders what the Presenter tells it to.
/// Owns no business logic and makes no networking calls.
final class DemoListViewController: UIViewController {

    // MARK: - MVP

    var presenter: DemoListPresenterProtocol!

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var items: [DemoScreenItem] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BDUI Demo"
        setupTableView()
        presenter.viewDidLoad()
    }

    // MARK: - Layout

    private func setupTableView() {
        tableView.dataSource  = self
        tableView.delegate    = self
        tableView.register(DemoCell.self, forCellReuseIdentifier: DemoCell.reuseId)
        view.addSubview(tableView)
        tableView.pinToEdges(of: view)
    }
}

// MARK: - DemoListViewProtocol

extension DemoListViewController: DemoListViewProtocol {
    func display(_ items: [DemoScreenItem]) {
        self.items = items
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension DemoListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.itemCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell  = tableView.dequeueReusableCell(withIdentifier: DemoCell.reuseId, for: indexPath) as! DemoCell
        let item  = presenter.item(at: indexPath.row)
        cell.configure(title: item.title, subtitle: item.subtitle)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DemoListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.didSelectItem(at: indexPath.row)
    }
}

// MARK: - Cell

private final class DemoCell: UITableViewCell {
    static let reuseId = "DemoCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        accessoryType    = .disclosureIndicator
        textLabel?.font  = .systemFont(ofSize: 16, weight: .medium)
        detailTextLabel?.textColor    = .secondaryLabel
        detailTextLabel?.numberOfLines = 2
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, subtitle: String) {
        textLabel?.text       = title
        detailTextLabel?.text = subtitle
    }
}
