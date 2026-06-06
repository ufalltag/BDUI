import UIKit
import BDUIClient

final class ContainerComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let stack = UIStackView()
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
        for (id, value) in map {
            childViews[id]?.update(with: value)
        }
    }

    func childView(for id: String) -> (any BDUIComponentView)? {
        childViews[id]
    }

    private func setupLayout(component: Component) {
        translatesAutoresizingMaskIntoConstraints = false
        stack.axis = directionFrom(component: component)
        stack.spacing = spacingFrom(props: component.props)
        switch component.kind {
        case "stats_row":
            stack.alignment = .fill
            stack.distribution = .fillEqually
        default:
            stack.alignment = .fill
            stack.distribution = .fill
        }
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func buildChildren(_ children: [Component], renderer: BDUIRenderer) {
        for child in children {
            let view = renderer.makeView(for: child)
            stack.addArrangedSubview(view)
            childViews[child.id] = view
            renderer.wireActions(view, for: child)
            renderer.registerView(view)
        }
    }

    private func directionFrom(component: Component) -> NSLayoutConstraint.Axis {
        if case .object(let map) = component.props,
           case .string(let dir) = map["direction"],
           dir == "horizontal" { return .horizontal }
        let horizontalKinds: Set<String> = ["stats_row", "action_bar", "rating_row", "price_row"]
        return horizontalKinds.contains(component.kind) ? .horizontal : .vertical
    }

    private func spacingFrom(props: JSONValue?) -> CGFloat {
        guard case .object(let map) = props,
              case .string(let s) = map["spacing"],
              let d = Double(s) else { return 8 }
        return CGFloat(d)
    }
}
