import UIKit
import BDUIClient

final class TabSwitcherComponentView: UIView, BDUIComponentView, BDUIActionAware {
    let componentId: String
    weak var actionDispatcher: BDUIActionDispatching?

    private let segmented = UISegmentedControl()

    init(component: Component) {
        self.componentId = component.id
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configureTabs(from: component.props)
        segmented.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        addSubview(segmented)
        segmented.pinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func segmentChanged() {
        let index = segmented.selectedSegmentIndex
        guard let title = segmented.titleForSegment(at: index) else { return }
        let fields: [String: JSONValue] = ["type": .string("select"),
                                           "target": .string(componentId),
                                           "value": .string(title.lowercased())]
        if let action = BDUIAction(from: .object(fields)) {
            actionDispatcher?.dispatch(action, from: componentId)
        }
    }

    func update(with dynamic: JSONValue) {
        guard case .object(let map) = dynamic,
              case .string(let selected) = map["selected_tab"] else { return }
        for i in 0..<segmented.numberOfSegments {
            if segmented.titleForSegment(at: i) == selected {
                segmented.selectedSegmentIndex = i
                break
            }
        }
    }

    private func configureTabs(from props: JSONValue?) {
        guard case .object(let map) = props,
              case .array(let tabs) = map["tabs"] else {
            segmented.insertSegment(withTitle: "Tab", at: 0, animated: false)
            segmented.selectedSegmentIndex = 0
            return
        }
        for (i, tab) in tabs.enumerated() {
            if case .string(let title) = tab {
                segmented.insertSegment(withTitle: title.capitalized, at: i, animated: false)
            }
        }
        segmented.selectedSegmentIndex = 0
    }
}
