import UIKit
import BDUIClient

final class FilterChipsComponentView: UIView, BDUIComponentView, BDUIActionAware {
    let componentId: String
    weak var actionDispatcher: BDUIActionDispatching?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    /// id of the currently highlighted chip (selection is handled locally).
    private var selectedId: String?

    /// When the component declares `action.type == "reload"`, tapping a chip
    /// re-fetches the screen for that category instead of just highlighting it.
    private let reloadsOnTap: Bool

    init(component: Component) {
        self.componentId = component.id
        self.reloadsOnTap = component.action?.type == "reload"
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        constrainSize(height: 36)

        scrollView.showsHorizontalScrollIndicator = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center

        addSubview(scrollView)
        scrollView.pinToEdges(of: self)
        scrollView.addSubview(stack)
        stack.pinToEdges(of: scrollView)
        stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .array(let chips) = dynamic else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for chip in chips {
            guard case .object(let map) = chip, case .string(let label) = map["label"] else { continue }
            let id = { if case .string(let v) = map["id"] { return v }; return label }()
            let selected = { if case .bool(let s) = map["selected"] { return s }; return false }()
            if selected { selectedId = id }
            stack.addArrangedSubview(makeChip(id: id, label: label, selected: id == selectedId))
        }
    }

    private func makeChip(id: String, label: String, selected: Bool) -> UIView {
        let chip = PaddedLabel()
        chip.text = label
        chip.font = UIFont.systemFont(ofSize: 14, weight: selected ? .semibold : .regular)
        chip.layer.cornerRadius = 16
        chip.clipsToBounds = true
        chip.textColor = selected ? .white : .label
        chip.backgroundColor = selected ? .systemBlue : .secondarySystemBackground
        chip.isUserInteractionEnabled = true
        chip.chipId = id
        chip.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chipTapped(_:))))
        return chip
    }

    @objc private func chipTapped(_ gesture: UITapGestureRecognizer) {
        guard let chip = gesture.view as? PaddedLabel, let id = chip.chipId else { return }
        selectedId = id
        restyle()

        let fields: [String: JSONValue] = reloadsOnTap
            ? ["type": .string("reload"), "category": .string(id)]
            : ["type": .string("select"), "target": .string(componentId), "value": .string(id)]
        if let action = BDUIAction(from: .object(fields)) {
            actionDispatcher?.dispatch(action, from: componentId)
        }
    }

    /// Re-applies highlight to every chip after a local selection change.
    private func restyle() {
        for case let chip as PaddedLabel in stack.arrangedSubviews {
            let selected = chip.chipId == selectedId
            chip.font = UIFont.systemFont(ofSize: 14, weight: selected ? .semibold : .regular)
            chip.textColor = selected ? .white : .label
            chip.backgroundColor = selected ? .systemBlue : .secondarySystemBackground
        }
    }
}

/// A label with internal padding, used for pill-shaped chips/badges.
final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
    /// Identifier of the chip this label represents (filter chips only).
    var chipId: String?

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
