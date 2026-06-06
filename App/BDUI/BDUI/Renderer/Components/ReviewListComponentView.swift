import UIKit
import BDUIClient

final class ReviewListComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let stack = UIStackView()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        addSubview(stack)
        stack.pinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .array(let reviews) = dynamic else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for review in reviews {
            guard case .object(let map) = review else { continue }
            stack.addArrangedSubview(makeReview(map))
        }
    }

    private func makeReview(_ map: [String: JSONValue]) -> UIView {
        let user = UILabel()
        user.font = UIFont.boldSystemFont(ofSize: 14)
        if case .string(let name) = map["user"] { user.text = name }

        let stars = UILabel()
        stars.font = UIFont.systemFont(ofSize: 13)
        stars.textColor = .systemOrange
        if case .number(let r) = map["rating"] { stars.text = starString(for: r) }

        let topRow = UIStackView(arrangedSubviews: [user, stars, UIView()])
        topRow.axis = .horizontal
        topRow.spacing = 8

        let text = UILabel()
        text.numberOfLines = 0
        text.font = UIFont.systemFont(ofSize: 14)
        if case .string(let t) = map["text"] { text.text = t }

        let date = UILabel()
        date.font = UIFont.systemFont(ofSize: 12)
        date.textColor = .secondaryLabel
        if case .string(let d) = map["date"] { date.text = d }

        let card = UIStackView(arrangedSubviews: [topRow, text, date])
        card.axis = .vertical
        card.spacing = 4
        return card
    }
}
