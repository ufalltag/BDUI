import UIKit
import BDUIClient

final class SortBarComponentView: UIView, BDUIComponentView, BDUIActionAware {
    let componentId: String
    weak var actionDispatcher: BDUIActionDispatching?

    private var selectedOption: String?

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        setup(props: component.props)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {}

    private func setup(props: JSONValue?) {
        translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Sort:"
        title.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [title])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center

        if case .object(let map) = props {
            if case .string(let def) = map["default"] { selectedOption = def }
            if case .array(let options) = map["options"] {
                for option in options {
                    guard case .string(let name) = option else { continue }
                    stack.addArrangedSubview(makeOption(name, selected: name == selectedOption))
                }
            }
        }
        stack.addArrangedSubview(UIView())

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        scrollView.pinToEdges(of: self)
        scrollView.addSubview(stack)
        stack.pinToEdges(of: scrollView)
        stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true
        self.optionsStack = stack
        constrainSize(height: 32)
    }

    private weak var optionsStack: UIStackView?

    private func makeOption(_ name: String, selected: Bool) -> UILabel {
        let label = OptionLabel()
        label.optionId = name
        label.text = name.replacingOccurrences(of: "_", with: " ").capitalized
        label.font = UIFont.systemFont(ofSize: 14, weight: selected ? .semibold : .regular)
        label.textColor = selected ? .systemBlue : .label
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:))))
        return label
    }

    @objc private func optionTapped(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? OptionLabel, let id = label.optionId else { return }
        selectedOption = id
        restyle()
        let fields: [String: JSONValue] = ["type": .string("select"),
                                           "target": .string(componentId),
                                           "value": .string(id)]
        if let action = BDUIAction(from: .object(fields)) {
            actionDispatcher?.dispatch(action, from: componentId)
        }
    }

    private func restyle() {
        guard let stack = optionsStack else { return }
        for case let label as OptionLabel in stack.arrangedSubviews {
            let selected = label.optionId == selectedOption
            label.font = UIFont.systemFont(ofSize: 14, weight: selected ? .semibold : .regular)
            label.textColor = selected ? .systemBlue : .label
        }
    }
}

/// A sort option label that remembers its raw identifier.
private final class OptionLabel: UILabel {
    var optionId: String?
}
