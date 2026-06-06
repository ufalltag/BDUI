import UIKit
import BDUIClient

final class StoriesCarouselComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .array(let stories) = dynamic else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for story in stories {
            guard case .object(let map) = story else { continue }
            stack.addArrangedSubview(makeStory(map))
        }
    }

    private func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        constrainSize(height: 92)

        scrollView.showsHorizontalScrollIndicator = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .top

        addSubview(scrollView)
        scrollView.pinToEdges(of: self)
        scrollView.addSubview(stack)
        stack.pinToEdges(of: scrollView)
        stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true
    }

    private func makeStory(_ map: [String: JSONValue]) -> UIView {
        let size: CGFloat = 64
        let ring = UIView()
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.layer.cornerRadius = size / 2
        ring.layer.borderWidth = 2.5
        let seen = { if case .bool(let s) = map["seen"] { return s }; return false }()
        ring.layer.borderColor = (seen ? UIColor.systemGray4 : UIColor.systemPink).cgColor
        ring.constrainSize(width: size, height: size)

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = (size - 8) / 2
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .systemGray5
        ring.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: size - 8),
            imageView.heightAnchor.constraint(equalToConstant: size - 8)
        ])
        if case .string(let url) = map["avatar"] { imageView.setRemoteImage(url) }

        let name = UILabel()
        name.font = UIFont.systemFont(ofSize: 11)
        name.textAlignment = .center
        if case .string(let user) = map["user"] { name.text = user }

        let column = UIStackView(arrangedSubviews: [ring, name])
        column.axis = .vertical
        column.spacing = 4
        column.alignment = .center
        column.widthAnchor.constraint(equalToConstant: size).isActive = true
        return column
    }
}
