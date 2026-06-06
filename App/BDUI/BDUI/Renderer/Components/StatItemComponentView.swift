import UIKit
import BDUIClient

final class StatItemComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let valueLabel = UILabel()
    private let titleLabel = UILabel()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        setupLayout()
        configure(with: component.props)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let props) = dynamic else { return }
        if case .string(let value) = props["value"] { valueLabel.text = value }
        if case .string(let title) = props["title"] { titleLabel.text = title }
        if case .string(let label) = props["label"] { titleLabel.text = label }
    }

    private func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = UIFont.boldSystemFont(ofSize: 20)
        valueLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func configure(with props: JSONValue?) {
        guard case .object(let map) = props else { return }
        if case .string(let value) = map["value"] { valueLabel.text = value }
        if case .string(let title) = map["title"] { titleLabel.text = title }
    }
}
