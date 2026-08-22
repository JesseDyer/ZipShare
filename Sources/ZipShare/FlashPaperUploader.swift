import Foundation

enum FlashPaperError: LocalizedError {
    case notConfigured, noData, parseFailed
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set your FlashPaper URL in Preferences first."
        case .noData: return "No response from FlashPaper."
        case .parseFailed: return "Couldn't find a URL in FlashPaper's response."
        case .httpError(let code, let body): return "FlashPaper returned \(code): \(body)"
        }
    }
}

enum FlashPaperUploader {
    /// FlashPaper (AndrewPaglusch/FlashPaper) takes a plain POST with the
    /// secret text and does its own server-side AES encryption — no
    /// client-side crypto needed. Response: {"url": "https://.../?k=..."}
    static func upload(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let base = ConfigStore.shared.flashPaperBaseURL else {
            completion(.failure(FlashPaperError.notConfigured))
            return
        }

        var request = URLRequest(url: base)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "secret": text,
            "json": "true"
        ]
        request.httpBody = bodyParams
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(FlashPaperError.noData)); return }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable>"
                completion(.failure(FlashPaperError.httpError(http.statusCode, bodyString)))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let url = json["url"] as? String else {
                completion(.failure(FlashPaperError.parseFailed))
                return
            }
            completion(.success(url))
        }.resume()
    }
}

private extension CharacterSet {
    /// application/x-www-form-urlencoded value encoding — stricter than
    /// .urlQueryAllowed, which leaves characters like & and + untouched.
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
