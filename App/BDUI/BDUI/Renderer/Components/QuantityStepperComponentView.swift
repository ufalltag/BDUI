import UIKit
import BDUIClient

final class QuantityStepperComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let valueLabel = UILabel()
    private var quantity = 1
    private var minValue = 1
    private var maxValue = 99

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        if case .object(let map) = component.props {
            if case .number(let min) = map["min"] { minValue = Int(min); quantity = Int(min) }
            if case .number(let max) = map["max"] { maxValue = Int(max) }
        }
        setupLayout()
        render()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        if case .number(let n) = dynamic { quantity = Int(n); render() }
        else if case .object(let map) = dynamic, case .number(let n) = map["quantity"] {
            quantity = Int(n); render()
        }
    }

    private func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Quantity"
        title.font = UIFont.systemFont(ofSize: 14, weight: .semibold)

        let minus = makeButton("minus", action: #selector(decrement))
        let plus = makeButton("plus", action: #selector(increment))
        valueLabel.font = UIFont.boldSystemFont(ofSize: 16)
        valueLabel.textAlignment = .center
        valueLabel.constrainSize(width: 36)

        let stepper = UIStackView(arrangedSubviews: [minus, valueLabel, plus])
        stepper.axis = .horizontal
        stepper.spacing = 8
        stepper.alignment = .center

        let stack = UIStackView(arrangedSubviews: [title, UIView(), stepper])
        stack.axis = .horizontal
        stack.alignment = .center
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    private func makeButton(_ symbol: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 8
        button.constrainSize(width: 32, height: 32)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func increment() { quantity = min(maxValue, quantity + 1); render() }
    @objc private func decrement() { quantity = max(minValue, quantity - 1); render() }

    private func render() { valueLabel.text = "\(quantity)" }
}
