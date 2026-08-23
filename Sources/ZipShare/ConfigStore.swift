import Foundation
import Security

final class ConfigStore {
    static let shared = ConfigStore()

    private let service = "org.jessedyer.zipshare"
    private let account = "apiToken"
    private let baseURLKey = "zipline.baseURL"
    private let shortLinkDomainKey = "zipline.shortLinkDomain"
    private let immichAccount = "immichApiKey"
    private let immichBaseURLKey = "immich.baseURL"
    private let flashPaperBaseURLKey = "flashpaper.baseURL"
    private let defaults = UserDefaults.standard

    var baseURL: URL? {
        get { defaults.string(forKey: baseURLKey).flatMap { URL(string: $0) } }
        set { defaults.set(newValue?.absoluteString, forKey: baseURLKey) }
    }

    var token: String? {
        get { KeychainHelper.read(service: service, account: account) }
        set {
            guard let newValue = newValue, !newValue.isEmpty else { return }
            KeychainHelper.save(newValue, service: service, account: account)
        }
    }

    var isConfigured: Bool {
        baseURL != nil && token != nil
    }

    var shortLinkDomain: URL? {
        get { defaults.string(forKey: shortLinkDomainKey).flatMap { URL(string: $0) } }
        set { defaults.set(newValue?.absoluteString, forKey: shortLinkDomainKey) }
    }

    var immichBaseURL: URL? {
        get { defaults.string(forKey: immichBaseURLKey).flatMap { URL(string: $0) } }
        set { defaults.set(newValue?.absoluteString, forKey: immichBaseURLKey) }
    }

    var immichAPIKey: String? {
        get { KeychainHelper.read(service: service, account: immichAccount) }
        set {
            guard let newValue = newValue, !newValue.isEmpty else { return }
            KeychainHelper.save(newValue, service: service, account: immichAccount)
        }
    }

    var isImmichConfigured: Bool {
        immichBaseURL != nil && immichAPIKey != nil
    }

    var flashPaperBaseURL: URL? {
        get { defaults.string(forKey: flashPaperBaseURLKey).flatMap { URL(string: $0) } }
        set { defaults.set(newValue?.absoluteString, forKey: flashPaperBaseURLKey) }
    }
}

enum KeychainHelper {
    static func save(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            print("[ZipShare] Keychain save failed, status \(status)")
        } else {
            print("[ZipShare] Keychain save OK for \(account)")
        }
    }

    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                print("[ZipShare] Keychain read status \(status) for \(account)")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
