import Foundation

enum ZiplineShortenError: LocalizedError {
    case notConfigured, noData, parseFailed
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set your Zipline URL and token in Preferences first."
        case .noData: return "No response from Zipline."
        case .parseFailed: return "Couldn't find a URL in Zipline's response."
        case .httpError(let code, let body): return "Zipline returned \(code): \(body)"
        }
    }
}

enum ZiplineShortener {
    /// POST /api/shorten -> {"url": "https://your-zipline.com/go/abc123"}.
    /// If a display domain is configured, rewrites that to
    /// {displayDomain}/abc123 — same id, shorter/prettier host.
    static func shorten(longURL: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let base = ConfigStore.shared.baseURL, let token = ConfigStore.shared.token else {
            completion(.failure(ZiplineShortenError.notConfigured))
            return
        }

        var request = URLRequest(url: base.appendingPathComponent("api/shorten"))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["url": longURL])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(ZiplineShortenError.noData)); return }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable>"
                completion(.failure(ZiplineShortenError.httpError(http.statusCode, bodyString)))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let shortURLString = json["url"] as? String else {
                completion(.failure(ZiplineShortenError.parseFailed))
                return
            }
            completion(.success(rewrite(shortURLString)))
        }.resume()
    }

    private static func rewrite(_ ziplineURLString: String) -> String {
        guard let displayBase = ConfigStore.shared.shortLinkDomain,
              let ziplineURL = URL(string: ziplineURLString) else {
            return ziplineURLString
        }
        let id = ziplineURL.lastPathComponent
        guard !id.isEmpty else { return ziplineURLString }
        return displayBase.appendingPathComponent(id).absoluteString
    }
}
