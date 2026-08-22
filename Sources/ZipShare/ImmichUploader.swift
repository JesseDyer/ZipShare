import Foundation

enum ImmichError: LocalizedError {
    case notConfigured, readFailed, noData, uploadParseFailed, shareParseFailed
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set your Immich URL and API key in Preferences first."
        case .readFailed: return "Couldn't read the file data."
        case .noData: return "No response from Immich."
        case .uploadParseFailed: return "Couldn't find an asset id in Immich's upload response."
        case .shareParseFailed: return "Couldn't find a share key in Immich's response."
        case .httpError(let code, let body): return "Immich returned \(code): \(body)"
        }
    }
}

enum ImmichUploader {
    /// Uploads an image asset, then creates a public "INDIVIDUAL" shared link
    /// for it, and returns that link — viewable without authentication.
    static func upload(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let base = ConfigStore.shared.immichBaseURL, let apiKey = ConfigStore.shared.immichAPIKey else {
            completion(.failure(ImmichError.notConfigured))
            return
        }

        uploadAsset(fileURL: fileURL, base: base, apiKey: apiKey) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let assetId):
                createSharedLink(assetId: assetId, base: base, apiKey: apiKey, completion: completion)
            }
        }
    }

    private static func uploadAsset(
        fileURL: URL, base: URL, apiKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(.failure(ImmichError.readFailed))
            return
        }

        var request = URLRequest(url: base.appendingPathComponent("api/assets"))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let filename = fileURL.lastPathComponent
        let mimeType = mimeTypeForPath(fileURL.path)
        let now = ISO8601DateFormatter().string(from: Date())
        let deviceAssetId = "zipshare-\(UUID().uuidString)"

        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        addField("deviceAssetId", deviceAssetId)
        addField("deviceId", "ZipShare")
        addField("fileCreatedAt", now)
        addField("fileModifiedAt", now)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"assetData\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(ImmichError.noData)); return }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable>"
                completion(.failure(ImmichError.httpError(http.statusCode, bodyString)))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? String else {
                completion(.failure(ImmichError.uploadParseFailed))
                return
            }
            print("[ZipShare] Immich asset uploaded, id=\(id)")
            completion(.success(id))
        }.resume()
    }

    private static func createSharedLink(
        assetId: String, base: URL, apiKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var request = URLRequest(url: base.appendingPathComponent("api/shared-links"))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // showMetadata is a shared-link display setting for Immich's own gallery
        // page; it doesn't affect the direct /original?key= URL we actually return,
        // but there's no harm leaving it off.
        let payload: [String: Any] = [
            "type": "INDIVIDUAL",
            "assetIds": [assetId],
            "allowDownload": true,
            "showMetadata": false
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(ImmichError.noData)); return }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable>"
                completion(.failure(ImmichError.httpError(http.statusCode, bodyString)))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(ImmichError.shareParseFailed))
                return
            }

            let shareViewerURL = json["key"].flatMap { key -> URL? in
                guard let key = key as? String else { return nil }
                return base.appendingPathComponent("share").appendingPathComponent(key)
            }

            if let key = json["key"] as? String {
                var components = URLComponents(
                    url: base.appendingPathComponent("api/assets/\(assetId)/original"),
                    resolvingAgainstBaseURL: false
                )
                components?.queryItems = [URLQueryItem(name: "key", value: key)]

                if let directURL = components?.url {
                    verifyDirect(directURL, fallback: shareViewerURL, completion: completion)
                    return
                }
            }

            if let fallback = shareViewerURL {
                completion(.success(fallback.absoluteString))
                return
            }
            if let url = findURL(in: json) {
                completion(.success(url))
                return
            }
            completion(.failure(ImmichError.shareParseFailed))
        }.resume()
    }

    /// The direct /original?key= route isn't part of Immich's documented API
    /// contract — it's speculative, sourced from a GitHub discussion rather
    /// than confirmed behavior. HEAD-check it before handing it back; if it
    /// doesn't resolve, fall back to the confirmed-working /share/{key}
    /// viewer link rather than returning a dead URL.
    private static func verifyDirect(
        _ directURL: URL, fallback: URL?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var request = URLRequest(url: directURL)
        request.httpMethod = "HEAD"

        URLSession.shared.dataTask(with: request) { _, response, error in
            let ok = (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
            if ok {
                print("[ZipShare] direct asset URL verified OK")
                completion(.success(directURL.absoluteString))
            } else {
                let status = (response as? HTTPURLResponse)?.statusCode
                print("[ZipShare] direct asset URL failed (status=\(String(describing: status)), error=\(String(describing: error))) — falling back to /share viewer link")
                if let fallback = fallback {
                    completion(.success(fallback.absoluteString))
                } else {
                    completion(.failure(ImmichError.shareParseFailed))
                }
            }
        }.resume()
    }

    private static func findURL(in obj: Any) -> String? {
        if let dict = obj as? [String: Any] {
            if let url = dict["url"] as? String { return url }
            for (_, value) in dict {
                if let found = findURL(in: value) { return found }
            }
        } else if let array = obj as? [Any] {
            for item in array {
                if let found = findURL(in: item) { return found }
            }
        }
        return nil
    }
}
