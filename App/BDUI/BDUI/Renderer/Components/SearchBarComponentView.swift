import UIKit
import BDUIClient

final class SearchBarComponentView: UIView, BDUIComponentView, BDUIActionAware {
    let componentId: String
    weak var actionDispatcher: BDUIActionDispatching?

    private let textField = UITextField()

    /// Optional component id this search filters; nil → all searchable views.
    private let target: String?

    init(component: Component) {
        self.componentId = component.id
        self.target = component.action?.string("target")
        super.init(frame: .zero)
        setup(props: component.props)
        textField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .search
        textField.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func searchChanged() {
        let query = textField.text ?? ""
        var fields: [String: JSONValue] = ["type": .string("search"), "query": .string(query)]
        if let target { fields["target"] = .string(target) }
        if let action = BDUIAction(from: .object(fields)) {
            actionDispatcher?.dispatch(action, from: componentId)
        }
    }

    func update(with dynamic: JSONValue) {
        guard case .object(let map) = dynamic,
              case .string(let placeholder) = map["placeholder"] else { return }
        textField.placeholder = placeholder
    }

    private func setup(props: JSONValue?) {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 10
        constrainSize(height: 40)

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        icon.constrainSize(width: 18, height: 18)

        textField.font = UIFont.systemFont(ofSize: 15)
        textField.borderStyle = .none
        if case .object(let map) = props, case .string(let placeholder) = map["placeholder"] {
            textField.placeholder = placeholder
        }

        let stack = UIStackView(arrangedSubviews: [icon, textField])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        addSubview(stack)
        stack.pinToEdges(of: self, insets: UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12))
    }
}

extension SearchBarComponentView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
