import UIKit
import BDUIClient

final class ExpandableSectionComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let titleButton = UIButton(type: .system)
    private let chevron = UIImageView()
    private let contentStack = UIStackView()
    private var childViews: [String: any BDUIComponentView] = [:]
    private var expanded = true

    init(component: Component, renderer: BDUIRenderer) {
        self.componentId = component.id
        super.init(frame: .zero)
        if case .object(let map) = component.props,
           case .bool(let exp) = map["initially_expanded"] {
            expanded = exp
        }
        setupLayout(component: component)
        buildChildren(component.children ?? [], renderer: renderer)
        applyExpanded()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let map) = dynamic else { return }
        for (id, value) in map { childViews[id]?.update(with: value) }
    }

    func childView(for id: String) -> (any BDUIComponentView)? { childViews[id] }

    private func setupLayout(component: Component) {
        translatesAutoresizingMaskIntoConstraints = false

        var title = ""
        if case .object(let map) = component.props, case .string(let t) = map["title"] { title = t }
        titleButton.setTitle(title, for: .normal)
        titleButton.setTitleColor(.label, for: .normal)
        titleButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        titleButton.contentHorizontalAlignment = .leading
        titleButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)

        chevron.tintColor = .secondaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.constrainSize(width: 14, height: 14)

        let header = UIStackView(arrangedSubviews: [titleButton, chevron])
        header.axis = .horizontal
        header.alignment = .center

        contentStack.axis = .vertical
        contentStack.spacing = 8

        let stack = UIStackView(arrangedSubviews: [header, contentStack])
        stack.axis = .vertical
        stack.spacing = 8
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func buildChildren(_ children: [Component], renderer: BDUIRenderer) {
        for child in children {
            let view = renderer.makeView(for: child)
            contentStack.addArrangedSubview(view)
            childViews[child.id] = view
            renderer.wireActions(view, for: child)
            renderer.registerView(view)
        }
    }

    @objc private func toggle() {
        expanded.toggle()
        applyExpanded()
    }

    private func applyExpanded() {
        contentStack.isHidden = !expanded
        let name = expanded ? "chevron.up" : "chevron.down"
        chevron.image = UIImage(systemName: name)
    }
}
