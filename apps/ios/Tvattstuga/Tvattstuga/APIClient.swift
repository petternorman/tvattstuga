import Foundation

private struct APIErrorResponse: Decodable {
    let error: String
}

enum APIClientError: LocalizedError {
    case missingBaseURL
    case invalidResponse
    case network(Error)
    case server(status: Int, message: String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "API base URL is missing. Set API_BASE_URL in your configuration."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .server(let status, let message):
            return "Server error \(status): \(message)"
        case .decoding:
            return "Could not read server data. The response format may have changed."
        }
    }
}

struct APIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchGroups(baseURL: URL, credentials: Credentials) async throws -> [ResourceGroup] {
        let endpoint = baseURL
            .appendingPathComponent("api", isDirectory: true)
            .appendingPathComponent("tvatt", isDirectory: false)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(credentials)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIClientError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let message = responseError?.error ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIClientError.server(status: httpResponse.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode([ResourceGroup].self, from: data)
        } catch {
            throw APIClientError.decoding(error)
        }
    }
}
