import UIKit
import BDUIClient

final class ImageGalleryComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let pageControl = UIPageControl()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(with dynamic: JSONValue) {
        guard case .array(let urls) = dynamic else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in urls {
            guard case .string(let url) = item else { continue }
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .systemGray6
            imageView.layer.cornerRadius = 12
            stack.addArrangedSubview(imageView)
            imageView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
            imageView.setRemoteImage(url)
        }
        pageControl.numberOfPages = stack.arrangedSubviews.count
    }

    private func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.75).isActive = true

        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        stack.axis = .horizontal

        addSubview(scrollView)
        scrollView.pinToEdges(of: self)
        scrollView.addSubview(stack)
        stack.pinToEdges(of: scrollView)
        stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true

        pageControl.currentPageIndicatorTintColor = .label
        pageControl.pageIndicatorTintColor = .systemGray3
        addSubview(pageControl)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
}

extension ImageGalleryComponentView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.frame.width > 0 else { return }
        pageControl.currentPage = Int((scrollView.contentOffset.x / scrollView.frame.width).rounded())
    }
}
