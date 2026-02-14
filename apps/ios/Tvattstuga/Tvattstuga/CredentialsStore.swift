import Foundation
import Security

protocol CredentialsStoring {
    func loadCredentials() -> Credentials?
    func saveCredentials(_ credentials: Credentials) throws
    func clearCredentials() throws
}

enum CredentialsStoreError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case clearFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Could not save credentials (keychain status \(status))."
        case .loadFailed(let status):
            return "Could not load credentials (keychain status \(status))."
        case .clearFailed(let status):
            return "Could not clear credentials (keychain status \(status))."
        }
    }
}

final class KeychainCredentialsStore: CredentialsStoring {
    private let service: String
    private let account = "tvattstuga.user.credentials"

    init(service: String = Bundle.main.bundleIdentifier ?? "tvattstuga.ios") {
        self.service = service
    }

    func loadCredentials() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            return nil
        }

        guard let data = item as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    func saveCredentials(_ credentials: Credentials) throws {
        let data = try JSONEncoder().encode(credentials)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw CredentialsStoreError.saveFailed(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CredentialsStoreError.saveFailed(addStatus)
        }
    }

    func clearCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw CredentialsStoreError.clearFailed(status)
    }
}
