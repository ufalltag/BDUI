import Foundation

/// Receives actions fired by component views and decides what to do
/// (navigate, refresh, show feedback, …). Implemented by the screen layer.
protocol BDUIActionDispatching: AnyObject {
    func dispatch(_ action: BDUIAction, from componentId: String)
}

/// Component views that fire their own (often per-item) actions adopt this
/// so the renderer can inject the shared dispatcher after construction.
protocol BDUIActionAware: AnyObject {
    var actionDispatcher: BDUIActionDispatching? { get set }
}

/// Component views that can filter their content by a search query
/// (e.g. a product grid). Driven locally by the search bar.
protocol BDUISearchable: AnyObject {
    func applyFilter(_ query: String)
}
