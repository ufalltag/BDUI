import UIKit
import BDUIClient

private let imageCache = NSCache<NSString, UIImage>()

final class AvatarComponentView: UIView, BDUIComponentView {
    let componentId: String

    private let circleView = UIView()
    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private var currentTask: URLSessionDataTask?

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
        if case .string(let bg) = props["background_color"] { circleView.backgroundColor = UIColor(hex: bg) }
        if case .string(let url) = props["url"] { loadImage(from: url) }
    }

    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("[Avatar] invalid URL: \(urlString)")
            return
        }

        if let cached = imageCache.object(forKey: urlString as NSString) {
            imageView.image = cached
            imageView.isHidden = false
            initialsLabel.isHidden = true
            return
        }

        currentTask?.cancel()
        print("[Avatar] loading: \(url)")
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error as? URLError, error.code == .cancelled { return }
            if let error { print("[Avatar] error: \(error)"); return }
            if let http = response as? HTTPURLResponse { print("[Avatar] status: \(http.statusCode)") }
            guard let self, let data, let image = UIImage(data: data) else {
                print("[Avatar] no data or decode failed, bytes: \(data?.count ?? 0)")
                return
            }
            imageCache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                self.imageView.image = image
                self.imageView.isHidden = false
                self.initialsLabel.isHidden = true
            }
        }
        currentTask = task
        task.resume()
    }

    private func sizeFrom(props: JSONValue?) -> CGFloat {
        guard case .object(let map) = props,
              case .string(let s) = map["size"] else { return 60 }
        switch s {
        case "small":  return 40
        case "medium": return 60
        case "large":  return 80
        default:       return CGFloat(Double(s) ?? 60)
        }
    }

    private func setupLayout(size: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        constrainSize(height: size)

        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.layer.cornerRadius = size / 2
        circleView.clipsToBounds = true
        circleView.backgroundColor = .systemGray4
        circleView.constrainSize(width: size, height: size)

        addSubview(circleView)
        NSLayoutConstraint.activate([
            circleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        initialsLabel.textAlignment = .center
        initialsLabel.font = UIFont.boldSystemFont(ofSize: size * 0.4)
        initialsLabel.textColor = .white
        circleView.addSubview(initialsLabel)
        initialsLabel.center(in: circleView)

        imageView.contentMode = .scaleAspectFill
        imageView.isHidden = true
        circleView.addSubview(imageView)
        imageView.pinToEdges(of: circleView)
    }

    private func configure(with props: JSONValue?) {
        guard case .object(let map) = props else { return }
        if case .string(let initials) = map["initials"] { initialsLabel.text = initials }
        if case .string(let bg) = map["background_color"] { circleView.backgroundColor = UIColor(hex: bg) }
    }
}
