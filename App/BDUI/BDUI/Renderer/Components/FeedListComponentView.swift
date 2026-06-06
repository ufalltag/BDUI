import UIKit
import BDUIClient

final class FeedListComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let stack = UIStackView()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .array(let posts) = dynamic else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for post in posts {
            guard case .object(let map) = post else { continue }
            stack.addArrangedSubview(makeCard(map))
        }
    }

    private func makeCard(_ map: [String: JSONValue]) -> UIView {
        let avatar = UIImageView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.layer.cornerRadius = 16
        avatar.clipsToBounds = true
        avatar.contentMode = .scaleAspectFill
        avatar.backgroundColor = .systemGray5
        avatar.constrainSize(width: 32, height: 32)
        if case .string(let url) = map["author_avatar"] { avatar.setRemoteImage(url) }

        let author = UILabel()
        author.font = UIFont.boldSystemFont(ofSize: 14)
        if case .string(let name) = map["author"] { author.text = name }

        let header = UIStackView(arrangedSubviews: [avatar, author, UIView()])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center

        let media = UIImageView()
        media.translatesAutoresizingMaskIntoConstraints = false
        media.contentMode = .scaleAspectFill
        media.clipsToBounds = true
        media.layer.cornerRadius = 8
        media.backgroundColor = .systemGray6
        media.heightAnchor.constraint(equalTo: media.widthAnchor).isActive = true
        if case .string(let url) = map["media_url"] { media.setRemoteImage(url) }

        let likes = UILabel()
        likes.font = UIFont.boldSystemFont(ofSize: 13)
        if case .number(let count) = map["likes"] { likes.text = "\(Int(count)) likes" }

        let caption = UILabel()
        caption.numberOfLines = 0
        caption.font = UIFont.systemFont(ofSize: 14)
        if case .string(let text) = map["caption"] {
            let authorName = { if case .string(let n) = map["author"] { return n }; return "" }()
            caption.text = authorName.isEmpty ? text : "\(authorName) \(text)"
        }

        let card = UIStackView(arrangedSubviews: [header, media, likes, caption])
        card.axis = .vertical
        card.spacing = 8
        return card
    }
}
