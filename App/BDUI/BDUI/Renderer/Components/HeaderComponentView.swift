import UIKit
import BDUIClient

final class HeaderComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        setupLayout()
        configure(with: component.props)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let props) = dynamic else { return }
        if case .string(let title) = props["title"] { titleLabel.text = title }
        if case .string(let subtitle) = props["subtitle"] { subtitleLabel.text = subtitle }
    }

    private func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.numberOfLines = 0
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func configure(with props: JSONValue?) {
        guard case .object(let map) = props else { return }
        if case .string(let title) = map["title"] { titleLabel.text = title }
        if case .string(let subtitle) = map["subtitle"] { subtitleLabel.text = subtitle }
    }
}
