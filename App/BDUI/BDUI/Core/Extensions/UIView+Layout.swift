import UIKit

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }

    func pinToEdges(of view: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom)
        ])
    }

    func pinToSafeArea(of view: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: guide.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -insets.bottom)
        ])
    }

    func constrainSize(width: CGFloat? = nil, height: CGFloat? = nil) {
        translatesAutoresizingMaskIntoConstraints = false
        if let w = width { widthAnchor.constraint(equalToConstant: w).isActive = true }
        if let h = height { heightAnchor.constraint(equalToConstant: h).isActive = true }
    }

    func center(in view: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
