import UIKit
import BDUIClient

final class BottomTabBarComponentView: UIView, BDUIComponentView {
    let componentId: String

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        setup(props: component.props)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {}

    private func setup(props: JSONValue?) {
        translatesAutoresizingMaskIntoConstraints = false
        constrainSize(height: 49)

        let topBorder = UIView()
        topBorder.backgroundColor = .separator
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBorder)
        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center

        if case .object(let map) = props, case .array(let tabs) = map["tabs"] {
            for tab in tabs {
                guard case .object(let t) = tab, case .string(let icon) = t["icon"] else { continue }
                let button = UIButton(type: .system)
                button.setImage(UIImage(systemName: iconName(for: icon)), for: .normal)
                button.tintColor = .label
                stack.addArrangedSubview(button)
            }
        }

        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func iconName(for icon: String) -> String {
        switch icon {
        case "house":  return "house"
        case "search": return "magnifyingglass"
        case "plus":   return "plus.app"
        case "person": return "person.crop.circle"
        default:       return icon
        }
    }
}
