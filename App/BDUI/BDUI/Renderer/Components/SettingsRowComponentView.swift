import UIKit
import BDUIClient

final class SettingsRowComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        setupLayout(component: component)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let map) = dynamic else { return }
        if case .string(let subtitle) = map["subtitle"] {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        }
        if case .string(let title) = map["title"] { titleLabel.text = title }
    }

    private func setupLayout(component: Component) {
        translatesAutoresizingMaskIntoConstraints = false
        constrainSize(height: 48)

        iconView.tintColor = .label
        iconView.contentMode = .scaleAspectFit
        iconView.constrainSize(width: 22, height: 22)

        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.text = title(for: component)

        subtitleLabel.font = UIFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.isHidden = true

        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 1

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.constrainSize(width: 12, height: 12)
        let showChevron = { if case .object(let m) = component.props, case .bool(let c) = m["chevron"] { return c }; return false }()
        chevron.isHidden = !showChevron

        if case .object(let map) = component.props, case .string(let icon) = map["icon"] {
            iconView.image = UIImage(systemName: icon)
        }

        let stack = UIStackView(arrangedSubviews: [iconView, labels, UIView(), chevron])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    /// Settings rows carry no title in the schema — derive a readable one from the id.
    private func title(for component: Component) -> String {
        if case .object(let map) = component.props, case .string(let t) = map["title"] { return t }
        return component.id
            .replacingOccurrences(of: "row_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
