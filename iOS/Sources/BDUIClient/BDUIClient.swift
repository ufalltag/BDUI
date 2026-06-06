import Foundation

// MARK: - Errors

public enum BDUIError: Error, LocalizedError {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:                   return "Invalid BDUI server URL"
        case .serverError(let code):        return "Server returned HTTP \(code)"
        case .decodingFailed(let error):    return "Decoding failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Protocol (for testability)

public protocol BDUIClientProtocol {
    func fetch(screenId: String, cachedKey: String?, dynamicKey: String?, category: String?) async throws -> BDUIServerResponse
}

extension BDUIClientProtocol {
    /// Back-compat convenience without a content variant.
    public func fetch(screenId: String, cachedKey: String?, dynamicKey: String?) async throws -> BDUIServerResponse {
        try await fetch(screenId: screenId, cachedKey: cachedKey, dynamicKey: dynamicKey, category: nil)
    }
}

// MARK: - URLSession implementation

public final class BDUIClient: BDUIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Fetch a screen from the server.
    /// - Parameters:
    ///   - cachedKey: The locally stored cache_key, or nil on first request.
    ///   - dynamicKey: The locally stored dynamic_key, or nil if not yet known.
    /// - Returns: Decoded server response (full, cache hit, or dynamic hit).
    public func fetch(screenId: String, cachedKey: String?, dynamicKey: String?, category: String?) async throws -> BDUIServerResponse {
        let url = try buildURL(screenId: screenId, cachedKey: cachedKey, dynamicKey: dynamicKey, category: category)
        let request = buildRequest(url: url)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BDUIError.serverError(statusCode: 0)
        }

        switch http.statusCode {
        case 200:
            do {
                return try decoder.decode(BDUIServerResponse.self, from: data)
            } catch {
                throw BDUIError.decodingFailed(error)
            }
        case 406:
            let versionError = (try? decoder.decode(BDUIVersionError.self, from: data))
                ?? BDUIVersionError(error: "unsupported_protocol_version",
                                    clientVersion: BDUIProtocol.currentVersion,
                                    supportedVersions: [])
            throw versionError
        default:
            throw BDUIError.serverError(statusCode: http.statusCode)
        }
    }

    /// Fetch protocol metadata (version, available screens).
    public func fetchMeta() async throws -> BDUIMeta {
        let url = baseURL.appendingPathComponent("/bdui/meta")
        let request = buildRequest(url: url)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BDUIError.serverError(statusCode: 0)
        }
        return try decoder.decode(BDUIMeta.self, from: data)
    }

    // MARK: - Private

    private func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("\(BDUIProtocol.currentVersion)", forHTTPHeaderField: "X-BDUI-Version")
        return request
    }

    private func buildURL(screenId: String, cachedKey: String?, dynamicKey: String?, category: String?) throws -> URL {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("/bdui/screen/\(screenId)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw BDUIError.invalidURL
        }
        var items: [URLQueryItem] = []
        if let key = cachedKey  { items.append(URLQueryItem(name: "cache_key",   value: key)) }
        if let key = dynamicKey { items.append(URLQueryItem(name: "dynamic_key", value: key)) }
        if let category         { items.append(URLQueryItem(name: "category",    value: category)) }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else { throw BDUIError.invalidURL }
        return url
    }
}
