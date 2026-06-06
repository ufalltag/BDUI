import UIKit
import BDUIClient

final class TopNavbarComponentView: UIView, BDUIComponentView {
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
        constrainSize(height: 44)

        let logo = UILabel()
        logo.text = "BDUI"
        logo.font = UIFont.boldSystemFont(ofSize: 22)

        let stack = UIStackView(arrangedSubviews: [logo, UIView()])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 16

        if case .object(let map) = props, case .array(let actions) = map["actions"] {
            for action in actions {
                guard case .string(let name) = action else { continue }
                let button = UIButton(type: .system)
                button.setImage(UIImage(systemName: iconName(for: name)), for: .normal)
                button.tintColor = .label
                stack.addArrangedSubview(button)
            }
        }

        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func iconName(for action: String) -> String {
        switch action {
        case "search":    return "magnifyingglass"
        case "messenger": return "paperplane"
        default:          return "circle"
        }
    }
}
