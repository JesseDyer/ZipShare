import Foundation
import UniformTypeIdentifiers

enum UploadError: LocalizedError {
    case notConfigured, readFailed, noData, parseFailed, httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set your Zipline URL and token in Preferences first."
        case .readFailed: return "Couldn't read the file data."
        case .noData: return "No response from server."
        case .parseFailed: return "Couldn't find a URL in the server response."
        case .httpError(let code, let body): return "Server returned \(code): \(body)"
        }
    }
}

enum ZiplineUploader {
    /// Uploads a file to Zipline's /api/upload endpoint and returns the
    /// resulting share URL. Parses the response generically (recursively
    /// hunting for a "url" key) since the exact response shape has drifted
    /// across Zipline versions.
    static func upload(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let base = ConfigStore.shared.baseURL, let token = ConfigStore.shared.token else {
            completion(.failure(UploadError.notConfigured))
            return
        }

        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(.failure(UploadError.readFailed))
            return
        }

        var request = URLRequest(url: base.appendingPathComponent("api/upload"))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let filename = fileURL.lastPathComponent
        let mimeType = mimeTypeForPath(fileURL.path)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(UploadError.noData))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let bodyString = String(data: data, encoding: .utf8) ?? "<unreadable>"
                completion(.failure(UploadError.httpError(http.statusCode, bodyString)))
                return
            }
            if let url = extractURL(from: data) {
                completion(.success(url))
            } else {
                completion(.failure(UploadError.parseFailed))
            }
        }.resume()
    }

    private static func extractURL(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return findURL(in: json)
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

func mimeTypeForPath(_ path: String) -> String {
    let ext = (path as NSString).pathExtension
    if let type = UTType(filenameExtension: ext), let mime = type.preferredMIMEType {
        return mime
    }
    return "application/octet-stream"
}
