import UIKit
import BDUIClient

final class VariantPickerComponentView: UIView, BDUIComponentView, BDUIActionAware {
    let componentId: String
    weak var actionDispatcher: BDUIActionDispatching?

    private let titleLabel = UILabel()
    private let swatchStack = UIStackView()

    /// id of the currently highlighted variant (selection is handled locally).
    private var selectedId: String?

    /// When the component declares `action.type == "reload"`, tapping a swatch
    /// re-fetches the screen for that variant instead of just highlighting it.
    private let reloadsOnTap: Bool

    init(component: Component) {
        self.componentId = component.id
        self.reloadsOnTap = component.action?.type == "reload"
        super.init(frame: .zero)
        setupLayout(props: component.props)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .array(let variants) = dynamic else { return }
        swatchStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for variant in variants {
            guard case .object(let map) = variant, case .string(let hex) = map["hex"] else { continue }
            let id = { if case .string(let v) = map["id"] { return v }; return hex }()
            let selected = { if case .bool(let s) = map["selected"] { return s }; return false }()
            if selected { selectedId = id }
            swatchStack.addArrangedSubview(makeSwatch(id: id, hex: hex, selected: id == selectedId))
        }
    }

    private func setupLayout(props: JSONValue?) {
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        if case .object(let map) = props, case .string(let label) = map["label"] {
            titleLabel.text = label
        }

        swatchStack.axis = .horizontal
        swatchStack.spacing = 10
        swatchStack.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, swatchStack, UIView()])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func makeSwatch(id: String, hex: String, selected: Bool) -> UIView {
        let swatch = SwatchView()
        swatch.variantId = id
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.backgroundColor = UIColor(hex: hex)
        swatch.layer.cornerRadius = 14
        swatch.layer.borderWidth = selected ? 2 : 0.5
        swatch.layer.borderColor = (selected ? UIColor.systemBlue : UIColor.systemGray3).cgColor
        swatch.constrainSize(width: 28, height: 28)
        swatch.isUserInteractionEnabled = true
        swatch.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(swatchTapped(_:))))
        return swatch
    }

    @objc private func swatchTapped(_ gesture: UITapGestureRecognizer) {
        guard let swatch = gesture.view as? SwatchView, let id = swatch.variantId else { return }
        selectedId = id
        restyle()
        let fields: [String: JSONValue] = reloadsOnTap
            ? ["type": .string("reload"), "category": .string(id)]
            : ["type": .string("select"), "target": .string(componentId), "value": .string(id)]
        if let action = BDUIAction(from: .object(fields)) {
            actionDispatcher?.dispatch(action, from: componentId)
        }
    }

    /// Re-applies the highlight border after a local selection change.
    private func restyle() {
        for case let swatch as SwatchView in swatchStack.arrangedSubviews {
            let selected = swatch.variantId == selectedId
            swatch.layer.borderWidth = selected ? 2 : 0.5
            swatch.layer.borderColor = (selected ? UIColor.systemBlue : UIColor.systemGray3).cgColor
        }
    }
}

/// A color swatch that remembers its variant identifier.
private final class SwatchView: UIView {
    var variantId: String?
}
