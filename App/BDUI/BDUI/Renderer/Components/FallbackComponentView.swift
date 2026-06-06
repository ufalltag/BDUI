import UIKit
import BDUIClient

final class FallbackComponentView: UIView, BDUIComponentView {
    let componentId: String

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        setup(type: component.kind)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {}

    private func setup(type: String) {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.systemYellow.withAlphaComponent(0.2)
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemYellow.cgColor

        let label = UILabel()
        label.text = "Unknown component: \(type)"
        label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        addSubview(label)
        label.pinToEdges(of: self, insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
    }
}
