import UIKit
import BDUIClient

final class SettingsGroupComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let titleLabel = UILabel()
    private let rowsStack = UIStackView()
    private var childViews: [String: any BDUIComponentView] = [:]

    init(component: Component, renderer: BDUIRenderer) {
        self.componentId = component.id
        super.init(frame: .zero)
        setupLayout(component: component)
        buildChildren(component.children ?? [], renderer: renderer)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let map) = dynamic else { return }
        for (id, value) in map { childViews[id]?.update(with: value) }
    }

    func childView(for id: String) -> (any BDUIComponentView)? { childViews[id] }

    private func setupLayout(component: Component) {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        if case .object(let map) = component.props, case .string(let title) = map["title"] {
            titleLabel.text = title.uppercased()
        }

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12

        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        card.addSubview(rowsStack)
        rowsStack.pinToEdges(of: card, insets: UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12))

        let stack = UIStackView(arrangedSubviews: [titleLabel, card])
        stack.axis = .vertical
        stack.spacing = 6
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func buildChildren(_ children: [Component], renderer: BDUIRenderer) {
        for (i, child) in children.enumerated() {
            let view = renderer.makeView(for: child)
            rowsStack.addArrangedSubview(view)
            childViews[child.id] = view
            renderer.wireActions(view, for: child)
            renderer.registerView(view)
            if i < children.count - 1 {
                let separator = UIView()
                separator.backgroundColor = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                rowsStack.addArrangedSubview(separator)
            }
        }
    }
}
