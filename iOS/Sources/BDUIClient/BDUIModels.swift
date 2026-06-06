import Foundation

// MARK: - JSONValue
// Represents arbitrary JSON — used for dynamic data whose schema varies per screen.

public indirect enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        // Bool must come before Double — both can decode from 0/1 in JSON.
        if let v = try? c.decode(Bool.self)               { self = .bool(v);   return }
        if let v = try? c.decode(Double.self)             { self = .number(v); return }
        if let v = try? c.decode(String.self)             { self = .string(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        if let v = try? c.decode([JSONValue].self)        { self = .array(v);  return }
        if c.decodeNil()                                  { self = .null;      return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unknown JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v):  try c.encode(v)
        case .null:          try c.encodeNil()
        }
    }
}

// MARK: - Static screen models (mirrors server's ui.StaticScreen)

public struct StaticScreen: Codable, Equatable {
    public let screenId: String
    public let layout: String
    public let navigation: NavigationConfig
    public let components: [Component]

    enum CodingKeys: String, CodingKey {
        case screenId = "screen_id"
        case layout, navigation, components
    }
}

public struct NavigationConfig: Codable, Equatable {
    public let tabBar: Bool
    public let tabIndex: Int?
    public let backButton: Bool
    public let title: String

    enum CodingKeys: String, CodingKey {
        case tabBar = "tab_bar"
        case tabIndex = "tab_index"
        case backButton = "back_button"
        case title
    }
}

// Component is a class — structs can't directly hold optional instances of themselves.
public final class Component: Codable, Equatable {
    public static func == (lhs: Component, rhs: Component) -> Bool {
        lhs.kind == rhs.kind && lhs.id == rhs.id &&
        lhs.props == rhs.props && lhs.style == rhs.style &&
        lhs.children == rhs.children && lhs.itemTemplate == rhs.itemTemplate
    }

    public let kind: String          // "type" in JSON — keyword in Swift
    public let id: String
    public let props: JSONValue?
    public let style: JSONValue?
    public let children: [Component]?
    public let itemTemplate: Component?

    enum CodingKeys: String, CodingKey {
        case kind = "type"
        case id, props, style, children
        case itemTemplate = "item_template"
    }

    public init(
        kind: String, id: String,
        props: JSONValue? = nil, style: JSONValue? = nil,
        children: [Component]? = nil, itemTemplate: Component? = nil
    ) {
        self.kind = kind; self.id = id
        self.props = props; self.style = style
        self.children = children; self.itemTemplate = itemTemplate
    }
}

// MARK: - Server response
// A single Decodable covers all three server responses:
//   Full:       { "ui": { "static": {...}, "dynamic": {...} }, "cache_key": "...", "dynamic_key": "..." }
//   CacheHit:   { "ui": { "dynamic": {...} }, "dynamic_key": "..." }
//   DynamicHit: { "cache_key": "...", "dynamic_key": "..." }  ← no "ui" at all

public struct BDUIServerResponse: Decodable {
    public let protocolVersion: Int
    public let ui: UIContent?       // nil → DynamicHit (nothing changed)
    public let cacheKey: String?    // nil → CacheHit (static unchanged)
    public let dynamicKey: String?  // present on CacheHit and DynamicHit

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case ui
        case cacheKey   = "cache_key"
        case dynamicKey = "dynamic_key"
    }

    public struct UIContent: Decodable {
        public let staticScreen: StaticScreen?   // nil → CacheHit
        public let dynamic: JSONValue

        enum CodingKeys: String, CodingKey {
            case staticScreen = "static"
            case dynamic
        }
    }

    public var isCacheHit: Bool   { ui != nil && cacheKey == nil }
    public var isDynamicHit: Bool { ui == nil }
}

// MARK: - ScreenData
// What the app actually renders: resolved static structure + current dynamic data.

public struct ScreenData: Equatable {
    public let staticScreen: StaticScreen
    public let dynamic: JSONValue
    public let cacheKey: String
    public let dynamicKey: String
}
