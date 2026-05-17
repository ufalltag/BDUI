import UIKit
import BDUIClient

final class TextComponentView: UILabel, BDUIComponentView {
    let componentId: String

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        configure(with: component.props)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let props) = dynamic else { return }
        if case .string(let text) = props["text"] { self.text = text }
        if case .string(let color) = props["color"] { textColor = UIColor(hex: color) }
    }

    private func configure(with props: JSONValue?) {
        numberOfLines = 0
        translatesAutoresizingMaskIntoConstraints = false
        guard case .object(let map) = props else { return }
        if case .string(let text) = map["text"] { self.text = text }
        if case .string(let size) = map["font_size"], let pt = Double(size) {
            font = UIFont.systemFont(ofSize: pt)
        }
        if case .string(let weight) = map["font_weight"] { applyWeight(weight) }
        if case .string(let align) = map["text_align"] { applyAlignment(align) }
        if case .string(let color) = map["color"] { textColor = UIColor(hex: color) }
    }

    private func applyWeight(_ weight: String) {
        let size = font.pointSize
        switch weight {
        case "bold":   font = UIFont.boldSystemFont(ofSize: size)
        case "medium": font = UIFont.systemFont(ofSize: size, weight: .medium)
        default:       font = UIFont.systemFont(ofSize: size)
        }
    }

    private func applyAlignment(_ align: String) {
        switch align {
        case "center": textAlignment = .center
        case "right":  textAlignment = .right
        default:       textAlignment = .left
        }
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
