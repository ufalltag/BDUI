import UIKit

/// Retains the action payload and forwards the tap to the dispatcher.
/// Stored on the view via associated object so the closure outlives the call.
private final class BDUIActionTapHandler: NSObject {
    private let action: BDUIAction
    private weak var dispatcher: BDUIActionDispatching?
    private let componentId: String

    init(action: BDUIAction, dispatcher: BDUIActionDispatching?, componentId: String) {
        self.action = action
        self.dispatcher = dispatcher
        self.componentId = componentId
    }

    @objc func fire() {
        dispatcher?.dispatch(action, from: componentId)
    }
}

extension UIView {
    private static var actionHandlerKey: UInt8 = 0

    /// Makes any view tappable, dispatching `action` when tapped.
    /// No-op when `action` is nil, so callers can pass it unconditionally.
    func bindAction(
        _ action: BDUIAction?,
        dispatcher: BDUIActionDispatching?,
        componentId: String
    ) {
        guard let action else { return }

        let handler = BDUIActionTapHandler(
            action: action,
            dispatcher: dispatcher,
            componentId: componentId
        )
        objc_setAssociatedObject(
            self, &UIView.actionHandlerKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        isUserInteractionEnabled = true
        addGestureRecognizer(
            UITapGestureRecognizer(target: handler, action: #selector(BDUIActionTapHandler.fire))
        )
    }
}
