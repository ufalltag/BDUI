import UIKit
import BDUIClient

/// Builds and updates a BDUI screen in two phases:
/// Phase 1 — `buildLayout`: constructs the full view hierarchy from StaticScreen (done once per layout version).
/// Phase 2 — `applyDynamic`: pushes new data into already-built views (done on every server response).
final class BDUIRenderer {

    private var componentViews: [String: any BDUIComponentView] = [:]

    // MARK: - Phase 1: Build

    func buildLayout(from screen: StaticScreen, in container: UIView) {
        componentViews.removeAll()
        container.subviews.forEach { $0.removeFromSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        stack.pinToEdges(of: container, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        for component in screen.components {
            if let view = makeView(for: component) {
                stack.addArrangedSubview(view)
                register(view, for: component)
            }
        }
    }

    // MARK: - Phase 2: Update

    func applyDynamic(_ dynamic: JSONValue) {
        guard case .object(let root) = dynamic else { return }

        for (id, value) in root {
            componentViews[id]?.update(with: value)
        }
    }

    // MARK: - Factory

    private func makeView(for component: Component) -> (any BDUIComponentView)? {
        switch component.kind {
        case "header":
            return HeaderComponentView(component: component)
        case "text":
            return TextComponentView(component: component)
        case "avatar":
            return AvatarComponentView(component: component)
        case "button":
            return ButtonComponentView(component: component)
        case "stat_item":
            return StatItemComponentView(component: component)
        case "container":
            return ContainerComponentView(component: component, renderer: self)
        default:
            return FallbackComponentView(component: component)
        }
    }

    private func register(_ view: any BDUIComponentView, for component: Component) {
        componentViews[component.id] = view
        if let children = component.children {
            for child in children {
                if let childView = (view as? ContainerComponentView)?.childView(for: child.id) {
                    componentViews[child.id] = childView
                }
            }
        }
    }

    func registerView(_ view: any BDUIComponentView) {
        componentViews[view.componentId] = view
    }
}
