import Foundation

enum ZAIError: LocalizedError {
    case invalidKey(String)
    case noCodingPlan(String)
    case server(code: Int, msg: String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidKey(let m):     return "Invalid API key: \(m)"
        case .noCodingPlan(let m):   return m
        case .server(let c, let m):  return "Server error \(c): \(m)"
        case .network(let m):        return "Network error: \(m)"
        }
    }
}

/// Common shape of z.ai monitor responses — the real status lives in the body.
protocol ZAIResponseBody: Decodable {
    var code: Int? { get }
    var msg: String? { get }
    var success: Bool? { get }
}

extension QuotaResponse: ZAIResponseBody {}
extension ModelUsageResponse: ZAIResponseBody {}

/// Talks to the (undocumented but stable) z.ai monitor endpoints.
/// The coding-plan API key works directly as a Bearer token — no JWT needed.
actor ZAIClient {
    static let shared = ZAIClient()

    private let host = "https://api.z.ai"
    private let session: URLSession
    /// `yyyy-MM-dd HH:mm:ss` range format required by the model-usage endpoint.
    private static let queryDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        // Hard cap: with waitsForConnectivity a request waits for the network
        // indefinitely and the refresh loop wedges, freezing the tray on stale data.
        cfg.timeoutIntervalForResource = 30
        session = URLSession(configuration: cfg)
    }

    func quotaLimit(apiKey: String) async throws -> QuotaResponse {
        let (data, resp) = try await authorizedData(url: URL(string: "\(host)/api/monitor/usage/quota/limit")!, apiKey: apiKey)
        try checkHTTP(resp, data: data)
        let decoded = try JSONDecoder().decode(QuotaResponse.self, from: data)
        try interpret(decoded)
        return decoded
    }

    /// Per-model token usage for the last `windowHours` (24h by default).
    /// The endpoint requires a `yyyy-MM-dd HH:mm:ss` local-time range.
    func modelUsage(apiKey: String, windowHours: Int = 24) async throws -> ModelUsageResponse {
        let f = Self.queryDateFormatter
        let now = Date()
        var comps = URLComponents(string: "\(host)/api/monitor/usage/model-usage")!
        comps.queryItems = [
            URLQueryItem(name: "startTime", value: f.string(from: now.addingTimeInterval(TimeInterval(-windowHours * 3600)))),
            URLQueryItem(name: "endTime", value: f.string(from: now)),
        ]
        let (data, resp) = try await authorizedData(url: comps.url!, apiKey: apiKey)
        try checkHTTP(resp, data: data)
        let decoded = try JSONDecoder().decode(ModelUsageResponse.self, from: data)
        try interpret(decoded)
        return decoded
    }

    // MARK: Internals

    private func authorizedData(url: URL, apiKey: String) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await session.data(for: authorized(req, apiKey: apiKey))
    }

    private func authorized(_ req: URLRequest, apiKey: String) -> URLRequest {
        var req = req
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func checkHTTP(_ resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ZAIError.invalidKey("HTTP \(http.statusCode)")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ZAIError.network("HTTP \(http.statusCode) \(body)")
        }
    }

    /// The API answers 200 even for logical failures; the real status lives in the body.
    private func interpret(_ r: ZAIResponseBody) throws {
        // A missing `success` flag with body code 200 is still a success —
        // the field is optional and could disappear from the undocumented API.
        // An explicit success:false always goes to the error path below.
        if r.success == true || (r.success == nil && r.code == 200) { return }
        let code = r.code ?? -1
        let msg = r.msg ?? ""

        // 1000 / 1001 = auth failures; 1309 = plan expired.
        if code == 1000 || code == 1001 || code == 1309 {
            throw ZAIError.invalidKey(msg.isEmpty ? "Authentication failed" : msg)
        }
        // "success:false" + a "coding plan" message = valid key, but no active plan.
        if msg.lowercased().contains("coding plan") {
            throw ZAIError.noCodingPlan("No active GLM Coding Plan for this key.")
        }
        throw ZAIError.server(code: code, msg: msg)
    }
}
