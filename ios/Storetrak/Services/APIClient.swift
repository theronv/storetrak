import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case serverError(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please log in again."
        case .serverError(let msg): return msg
        case .decodingError(let e): return "Data error: \(e.localizedDescription)"
        }
    }
}

struct APIClient {
    static let base = "https://storetrak-api.theronv.workers.dev"

    static func request<T: Decodable>(
        _ method: String,
        path: String,
        body: (some Encodable)? = nil as String?
    ) async throws -> T {
        guard let url = URL(string: "\(base)/\(path)") else {
            throw APIError.serverError("Invalid URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthManager.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError("No response")
        }
        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIError.serverError(msg)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // Variant that returns nothing (for DELETE, bulk ops, etc.)
    @discardableResult
    static func send(
        _ method: String,
        path: String,
        body: (some Encodable)? = nil as String?
    ) async throws -> [String: String] {
        return try await request(method, path: path, body: body)
    }

    static func login(email: String, password: String) async throws -> String {
        struct Creds: Encodable { let email, password: String }
        struct AuthResponse: Decodable { let token: String }
        let res: AuthResponse = try await request("POST", path: "auth/login", body: Creds(email: email, password: password))
        return res.token
    }

    static func register(email: String, password: String) async throws -> String {
        struct Creds: Encodable { let email, password: String }
        struct AuthResponse: Decodable { let token: String }
        let res: AuthResponse = try await request("POST", path: "auth/register", body: Creds(email: email, password: password))
        return res.token
    }

    static func forgotPassword(email: String) async throws {
        struct Body: Encodable { let email: String }
        let _: [String: String] = try await request("POST", path: "auth/forgot-password", body: Body(email: email))
    }

    static func resetPassword(email: String, token: String, password: String) async throws {
        struct Body: Encodable { let email, token, password: String }
        let _: [String: String] = try await request("POST", path: "auth/reset-password", body: Body(email: email, token: token, password: password))
    }

    static func changePassword(currentPassword: String, newPassword: String) async throws {
        struct Body: Encodable { let currentPassword, newPassword: String }
        let _: [String: String] = try await request("POST", path: "auth/change-password", body: Body(currentPassword: currentPassword, newPassword: newPassword))
    }
}
