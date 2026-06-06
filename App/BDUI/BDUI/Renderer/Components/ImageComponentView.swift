import UIKit
import BDUIClient

final class ImageComponentView: UIImageView, BDUIComponentView {
    let componentId: String

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = .systemGray6
        if case .object(let map) = component.props {
            if case .number(let radius) = map["corner_radius"] { layer.cornerRadius = radius }
            if case .string(let ratio) = map["aspect_ratio"] { applyAspectRatio(ratio) }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        switch dynamic {
        case .string(let url):
            setRemoteImage(url)
        case .object(let map):
            if case .string(let url) = map["url"] ?? map["src"] { setRemoteImage(url) }
        default:
            break
        }
    }

    private func applyAspectRatio(_ ratio: String) {
        let parts = ratio.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2, parts[0] > 0 else { return }
        heightAnchor.constraint(equalTo: widthAnchor, multiplier: parts[1] / parts[0]).isActive = true
    }
}
