import UIKit
import BDUIClient

final class ProductGridComponentView: UIView, BDUIComponentView, BDUISearchable {
    let componentId: String

    private var columns = 2
    private let stack = UIStackView()

    /// Full, unfiltered product set from the last dynamic update.
    private var allProducts: [JSONValue] = []
    private var currentQuery = ""

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        if case .object(let map) = component.props, case .number(let cols) = map["columns"] {
            columns = max(1, Int(cols))
        }
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fill
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .array(let products) = dynamic else { return }
        allProducts = products
        render(productsMatching(currentQuery))
    }

    // MARK: - BDUISearchable

    func applyFilter(_ query: String) {
        currentQuery = query
        render(productsMatching(query))
    }

    /// Case-insensitive match on the product `name`. Empty query → all products.
    private func productsMatching(_ query: String) -> [JSONValue] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allProducts }
        return allProducts.filter { product in
            guard case .object(let map) = product, case .string(let name)? = map["name"] else { return false }
            return name.lowercased().contains(q)
        }
    }

    private func render(_ products: [JSONValue]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var row: [UIView] = []
        for (i, product) in products.enumerated() {
            guard case .object(let map) = product else { continue }
            row.append(makeCard(map))
            if row.count == columns || i == products.count - 1 {
                while row.count < columns {
                    let spacer = UIView()
                    spacer.translatesAutoresizingMaskIntoConstraints = false
                    row.append(spacer)
                }
                let rowStack = UIStackView(arrangedSubviews: row)
                rowStack.axis = .horizontal
                rowStack.spacing = 12
                rowStack.distribution = .fillEqually
                rowStack.alignment = .top
                stack.addArrangedSubview(rowStack)
                row = []
            }
        }
    }

    private func makeCard(_ map: [String: JSONValue]) -> UIView {
        let image = UIView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.backgroundColor = .systemGray5
        image.layer.cornerRadius = 12
        image.heightAnchor.constraint(equalTo: image.widthAnchor).isActive = true

        if case .string(let badge) = map["badge"] {
            let badgeLabel = PaddedLabel()
            badgeLabel.insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
            badgeLabel.text = badge
            badgeLabel.font = UIFont.boldSystemFont(ofSize: 11)
            badgeLabel.textColor = .white
            badgeLabel.backgroundColor = .systemRed
            badgeLabel.layer.cornerRadius = 8
            badgeLabel.clipsToBounds = true
            image.addSubview(badgeLabel)
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                badgeLabel.topAnchor.constraint(equalTo: image.topAnchor, constant: 8),
                badgeLabel.leadingAnchor.constraint(equalTo: image.leadingAnchor, constant: 8)
            ])
        }

        let name = UILabel()
        name.numberOfLines = 2
        name.font = UIFont.systemFont(ofSize: 14)
        if case .string(let n) = map["name"] { name.text = n }

        let rating = UILabel()
        rating.font = UIFont.systemFont(ofSize: 12)
        rating.textColor = .secondaryLabel
        if case .number(let r) = map["rating"] {
            let reviews = { if case .number(let c) = map["reviews"] { return " (\(Int(c)))" }; return "" }()
            rating.text = "\(starString(for: r)) \(r)\(reviews)"
        }

        let price = UILabel()
        price.font = UIFont.boldSystemFont(ofSize: 16)
        if case .string(let p) = map["price"] { price.text = p }

        let card = UIStackView(arrangedSubviews: [image, name, rating, price])
        card.axis = .vertical
        card.spacing = 4
        return card
    }
}
