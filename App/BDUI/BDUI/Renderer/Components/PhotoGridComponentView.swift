import UIKit
import BDUIClient

final class PhotoGridComponentView: UIView, BDUIComponentView {
    let componentId: String

    private var columns: Int = 3
    private var items: [UIView] = []
    private let container = UIView()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        if case .object(let map) = component.props,
           case .number(let cols) = map["columns"] {
            columns = max(1, Int(cols))
        }
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.pinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .object(let map) = dynamic,
              case .array(let urls) = map["items"] else { return }
        rebuild(with: urls)
    }

    private func rebuild(with items: [JSONValue]) {
        container.subviews.forEach { $0.removeFromSuperview() }
        self.items = []

        let spacing: CGFloat = 2
        var rowStacks: [UIStackView] = []

        var row: [UIView] = []
        for (i, item) in items.enumerated() {
            let cell = makeCell(from: item)
            row.append(cell)
            if row.count == columns || i == items.count - 1 {
                while row.count < columns {
                    let spacer = UIView()
                    spacer.translatesAutoresizingMaskIntoConstraints = false
                    row.append(spacer)
                }
                let rowStack = UIStackView(arrangedSubviews: row)
                rowStack.axis = .horizontal
                rowStack.spacing = spacing
                rowStack.distribution = .fillEqually
                rowStacks.append(rowStack)
                row = []
            }
        }

        let vStack = UIStackView(arrangedSubviews: rowStacks)
        vStack.axis = .vertical
        vStack.spacing = spacing
        vStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(vStack)
        vStack.pinToEdges(of: container)
    }

    private func makeCell(from item: JSONValue) -> UIView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.systemGray5
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor).isActive = true

        if case .object(let map) = item,
           case .string(let urlString) = map["thumbnail"],
           let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { [weak imageView] data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async { imageView?.image = image }
            }.resume()
        }

        return imageView
    }
}
