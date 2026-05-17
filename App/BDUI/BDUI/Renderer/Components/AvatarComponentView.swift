import UIKit
import BDUIClient

final class AvatarComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let imageView = UIImageView()
    private let initialsLabel = UILabel()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        let size = sizeFrom(props: component.props)
        setupLayout(size: size)
        configure(with: component.props)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let props) = dynamic else { return }
        if case .string(let initials) = props["initials"] { initialsLabel.text = initials }
        if case .string(let bg) = props["background_color"] { backgroundColor = UIColor(hex: bg) }
    }

    private func sizeFrom(props: JSONValue?) -> CGFloat {
        guard case .object(let map) = props,
              case .string(let s) = map["size"],
              let d = Double(s) else { return 60 }
        return CGFloat(d)
    }

    private func setupLayout(size: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        constrainSize(width: size, height: size)
        layer.cornerRadius = size / 2
        clipsToBounds = true

        initialsLabel.textAlignment = .center
        initialsLabel.font = UIFont.boldSystemFont(ofSize: size * 0.4)
        initialsLabel.textColor = .white
        addSubview(initialsLabel)
        initialsLabel.center(in: self)

        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        imageView.pinToEdges(of: self)
        imageView.isHidden = true
    }

    private func configure(with props: JSONValue?) {
        guard case .object(let map) = props else { return }
        if case .string(let initials) = map["initials"] { initialsLabel.text = initials }
        if case .string(let bg) = map["background_color"] { backgroundColor = UIColor(hex: bg) }
    }
}
