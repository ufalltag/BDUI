import Foundation
import BDUIClient

/// A server-driven action parsed from a component's `props.action`
/// (or a per-item `action` field inside dynamic data).
///
/// Shape is open, discriminated by `type`:
///   { "type": "navigate", "screen": "product" }
///   { "type": "select",   "target": "filters", "value": "electronics" }
///   { "type": "refresh" }
///
/// Unknown `type`s are allowed — the dispatcher falls back to showing the
/// action name, so authoring a new action never crashes the client.
struct BDUIAction: Equatable {
    let type: String
    private let fields: [String: JSONValue]

    /// Parses an action object. Returns `nil` for anything that isn't an
    /// object carrying a string `type`.
    init?(from value: JSONValue?) {
        guard case .object(let map) = value,
              case .string(let type)? = map["type"] else { return nil }
        self.type = type
        self.fields = map
    }

    private init(type: String, fields: [String: JSONValue]) {
        self.type = type
        self.fields = fields
    }

    /// Wraps a legacy string action (e.g. `"action": "logout"`) so existing
    /// screens keep working without an object payload.
    static func named(_ name: String) -> BDUIAction {
        BDUIAction(type: "tap", fields: ["type": .string("tap"), "name": .string(name)])
    }

    func string(_ key: String) -> String? {
        if case .string(let s)? = fields[key] { return s }
        return nil
    }

    func int(_ key: String) -> Int? {
        if case .number(let n)? = fields[key] { return Int(n) }
        return nil
    }

    /// Human-readable label for fallback alerts / logging.
    var displayName: String {
        let raw = string("name") ?? string("screen") ?? string("value") ?? type
        return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Component convenience

extension Component {
    /// The action attached to this component via `props.action`, if any.
    /// Supports both object form and the legacy bare-string form.
    var action: BDUIAction? {
        guard case .object(let map)? = props else { return nil }
        if let object = BDUIAction(from: map["action"]) { return object }
        if case .string(let name)? = map["action"] { return .named(name) }
        return nil
    }
}
