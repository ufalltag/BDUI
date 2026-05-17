import UIKit
import BDUIClient

final class ButtonComponentView: UIButton, BDUIComponentView {
    let componentId: String

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        configure(with: component.props)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let props) = dynamic else { return }
        if case .string(let title) = props["title"] { setTitle(title, for: .normal) }
        if case .bool(let enabled) = props["enabled"] { isEnabled = enabled }
    }

    private func configure(with props: JSONValue?) {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 10
        clipsToBounds = true
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        constrainSize(height: 48)

        guard case .object(let map) = props else {
            backgroundColor = .systemBlue
            setTitleColor(.white, for: .normal)
            return
        }
        if case .string(let title) = map["title"] { setTitle(title, for: .normal) }
        if case .string(let bg) = map["background_color"] {
            backgroundColor = UIColor(hex: bg)
        } else {
            backgroundColor = .systemBlue
        }
        if case .string(let color) = map["text_color"] {
            setTitleColor(UIColor(hex: color), for: .normal)
        } else {
            setTitleColor(.white, for: .normal)
        }
    }
}
