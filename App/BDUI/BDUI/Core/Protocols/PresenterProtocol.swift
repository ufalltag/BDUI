import Foundation

/// Minimum contract every Presenter must satisfy.
/// Views call `viewDidLoad()` once and the Presenter drives everything from there.
protocol PresenterProtocol: AnyObject {
    func viewDidLoad()
}
