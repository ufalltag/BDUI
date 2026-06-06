import UIKit
import BDUIClient

final class SettingsToggleComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let iconView = UIImageView()
    private let label = UILabel()
    private let toggle = UISwitch()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        setupLayout(component: component)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let map) = dynamic, case .bool(let enabled) = map["enabled"] else { return }
        toggle.setOn(enabled, animated: false)
    }

    private func setupLayout(component: Component) {
        translatesAutoresizingMaskIntoConstraints = false
        constrainSize(height: 48)

        iconView.tintColor = .label
        iconView.contentMode = .scaleAspectFit
        iconView.constrainSize(width: 22, height: 22)

        label.font = UIFont.systemFont(ofSize: 16)

        if case .object(let map) = component.props {
            if case .string(let icon) = map["icon"] { iconView.image = UIImage(systemName: icon) }
            if case .string(let text) = map["label"] { label.text = text }
        }

        toggle.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [iconView, label, UIView(), toggle])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        addSubview(stack)
        stack.pinToEdges(of: self)
    }
}
