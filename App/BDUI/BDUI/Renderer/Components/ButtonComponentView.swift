import UIKit
import BDUIClient

final class ButtonComponentView: UIButton, BDUIComponentView, BDUIActionAware {
    let componentId: String
    weak var actionDispatcher: BDUIActionDispatching?
    private var action: BDUIAction?

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        self.action = component.action
        configure(with: component.props)
        addTarget(self, action: #selector(didTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let props) = dynamic else { return }
        if case .string(let title) = props["title"] { setTitle(title, for: .normal) }
        if case .bool(let enabled) = props["enabled"] { isEnabled = enabled }
    }

    @objc private func didTap() {
        guard let action else { return }
        if let dispatcher = actionDispatcher {
            dispatcher.dispatch(action, from: componentId)
        } else {
            // Standalone fallback when no dispatcher is wired (e.g. previews).
            guard let vc = findViewController() else { return }
            let alert = UIAlertController(title: action.displayName, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            vc.present(alert, animated: true)
        }
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }

    private func configure(with props: JSONValue?) {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 10
        clipsToBounds = true
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        constrainSize(height: 48)

        guard case .object(let map) = props else {
            applyStyle("primary")
            return
        }
        // Title: explicit prop, else derived from the action (schema often omits it).
        if case .string(let title) = map["title"] {
            setTitle(title, for: .normal)
        } else if let action {
            setTitle(action.displayName, for: .normal)
        }

        if case .string(let style) = map["style"] { applyStyle(style) } else { applyStyle("primary") }
        if case .string(let bg) = map["background_color"] { backgroundColor = UIColor(hex: bg) }
        if case .string(let color) = map["text_color"] { setTitleColor(UIColor(hex: color), for: .normal) }
    }

    private func applyStyle(_ style: String) {
        layer.borderWidth = 0
        switch style {
        case "secondary":
            backgroundColor = .secondarySystemBackground
            setTitleColor(.label, for: .normal)
        case "outline":
            backgroundColor = .clear
            setTitleColor(.systemBlue, for: .normal)
            layer.borderWidth = 1
            layer.borderColor = UIColor.systemBlue.cgColor
        case "destructive":
            backgroundColor = .systemRed
            setTitleColor(.white, for: .normal)
        default: // primary
            backgroundColor = .systemBlue
            setTitleColor(.white, for: .normal)
        }
    }
}
