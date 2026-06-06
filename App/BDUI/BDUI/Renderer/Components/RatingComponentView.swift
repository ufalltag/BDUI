import UIKit
import BDUIClient

final class RatingComponentView: UILabel, BDUIComponentView {
    let componentId: String
    private var maxStars = 5

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        font = UIFont.systemFont(ofSize: 15)
        textColor = .systemOrange
        if case .object(let map) = component.props, case .number(let max) = map["max_stars"] {
            maxStars = Int(max)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        let value: Double
        switch dynamic {
        case .number(let n): value = n
        case .object(let map):
            guard case .number(let n) = map["rating"] ?? map["value"] else { return }
            value = n
        default: return
        }
        text = "\(starString(for: value, max: maxStars)) \(value)"
    }
}
