import UIKit
import BDUIClient

/// Builds and updates a BDUI screen in two phases:
/// Phase 1 — `buildLayout`: constructs the full view hierarchy from StaticScreen (done once per layout version).
/// Phase 2 — `applyDynamic`: pushes new data into already-built views (done on every server response).
final class BDUIRenderer {

    private var componentViews: [String: any BDUIComponentView] = [:]

    /// Handles actions fired by component views. Set by the owning screen.
    weak var actionDispatcher: BDUIActionDispatching?

    // MARK: - Phase 1: Build

    func buildLayout(from screen: StaticScreen, in container: UIView) {
        componentViews.removeAll()
        container.subviews.forEach { $0.removeFromSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        stack.pinToEdges(of: container, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        for component in screen.components {
            let view = makeView(for: component)
            stack.addArrangedSubview(view)
            wireActions(view, for: component)
            register(view, for: component)
        }
    }

    /// Wires actions for a freshly built view:
    /// - injects the shared dispatcher into views that fire their own actions
    /// - attaches a generic tap for any component carrying `props.action`
    func wireActions(_ view: any BDUIComponentView, for component: Component) {
        // Action-aware views handle their own (often per-item) taps — injecting
        // the dispatcher is enough. A generic whole-view tap is only added to
        // "passive" components that don't manage interaction themselves.
        if let aware = view as? BDUIActionAware {
            aware.actionDispatcher = actionDispatcher
        } else {
            view.bindAction(component.action, dispatcher: actionDispatcher, componentId: component.id)
        }
    }

    /// Applies a search query to searchable components.
    /// `target` limits it to one component; nil filters every searchable view.
    func applyFilter(target: String?, query: String) {
        if let target, let view = componentViews[target] as? BDUISearchable {
            view.applyFilter(query)
            return
        }
        for view in componentViews.values {
            (view as? BDUISearchable)?.applyFilter(query)
        }
    }

    // MARK: - Phase 2: Update

    func applyDynamic(_ dynamic: JSONValue) {
        guard case .object(let root) = dynamic else { return }

        for (id, value) in root {
            componentViews[id]?.update(with: value)
        }
    }

    // MARK: - Factory

    func makeView(for component: Component) -> any BDUIComponentView {
        switch component.kind {
        case "header":
            return HeaderComponentView(component: component)
        case "text":
            return TextComponentView(component: component)
        case "avatar":
            return AvatarComponentView(component: component)
        case "button":
            return ButtonComponentView(component: component)
        case "stat_item":
            return StatItemComponentView(component: component)
        case "container", "profile_hero", "stats_row",
             "product_info", "rating_row", "price_row", "sticky_footer":
            return ContainerComponentView(component: component, renderer: self)
        case "tab_switcher":
            return TabSwitcherComponentView(component: component)
        case "photo_grid":
            return PhotoGridComponentView(component: component)
        case "image":
            return ImageComponentView(component: component)
        case "rating":
            return RatingComponentView(component: component)
        // Home
        case "top_navbar":
            return TopNavbarComponentView(component: component)
        case "stories_carousel":
            return StoriesCarouselComponentView(component: component)
        case "feed_list":
            return FeedListComponentView(component: component)
        case "bottom_tab_bar":
            return BottomTabBarComponentView(component: component)
        // Catalog
        case "search_bar":
            return SearchBarComponentView(component: component)
        case "filter_chips":
            return FilterChipsComponentView(component: component)
        case "sort_bar":
            return SortBarComponentView(component: component)
        case "product_grid":
            return ProductGridComponentView(component: component)
        // Product
        case "image_gallery":
            return ImageGalleryComponentView(component: component)
        case "variant_picker":
            return VariantPickerComponentView(component: component)
        case "quantity_stepper":
            return QuantityStepperComponentView(component: component)
        case "expandable_section":
            return ExpandableSectionComponentView(component: component, renderer: self)
        case "review_list":
            return ReviewListComponentView(component: component)
        // Settings
        case "settings_group":
            return SettingsGroupComponentView(component: component, renderer: self)
        case "settings_row":
            return SettingsRowComponentView(component: component)
        case "settings_toggle":
            return SettingsToggleComponentView(component: component)
        default:
            return FallbackComponentView(component: component)
        }
    }

    private func register(_ view: any BDUIComponentView, for component: Component) {
        componentViews[component.id] = view
        if let children = component.children {
            for child in children {
                if let childView = (view as? ContainerComponentView)?.childView(for: child.id) {
                    componentViews[child.id] = childView
                }
            }
        }
    }

    func registerView(_ view: any BDUIComponentView) {
        componentViews[view.componentId] = view
    }
}
