import UIKit
import BDUIClient

protocol BDUIComponentView: UIView {
    var componentId: String { get }
    func update(with dynamic: JSONValue)
}
