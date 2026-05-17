import UIKit
import BDUIClient

final class ContainerComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let stack = UIStackView()
    private var childViews: [String: any BDUIComponentView] = [:]

    init(component: Component, renderer: BDUIRenderer) {
        self.componentId = component.id
        super.init(frame: .zero)
        setupLayout(direction: directionFrom(props: component.props), spacing: spacingFrom(props: component.props))
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

    private func setupLayout(direction: NSLayoutConstraint.Axis, spacing: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        stack.axis = direction
        stack.spacing = spacing
        stack.alignment = .fill
        stack.distribution = .fill
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func buildChildren(_ children: [Component], renderer: BDUIRenderer) {
        for child in children {
            let view = makeView(for: child, renderer: renderer)
            stack.addArrangedSubview(view)
            childViews[child.id] = view
            renderer.registerView(view)
        }
    }

    private func makeView(for component: Component, renderer: BDUIRenderer) -> any BDUIComponentView {
        switch component.kind {
        case "header":    return HeaderComponentView(component: component)
        case "text":      return TextComponentView(component: component)
        case "avatar":    return AvatarComponentView(component: component)
        case "button":    return ButtonComponentView(component: component)
        case "stat_item": return StatItemComponentView(component: component)
        case "container": return ContainerComponentView(component: component, renderer: renderer)
        default:          return FallbackComponentView(component: component)
        }
    }

    private func directionFrom(props: JSONValue?) -> NSLayoutConstraint.Axis {
        guard case .object(let map) = props,
              case .string(let dir) = map["direction"],
              dir == "horizontal" else { return .vertical }
        return .horizontal
    }

    private func spacingFrom(props: JSONValue?) -> CGFloat {
        guard case .object(let map) = props,
              case .string(let s) = map["spacing"],
              let d = Double(s) else { return 8 }
        return CGFloat(d)
    }
}
