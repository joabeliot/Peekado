import Foundation
import Security

/// A tiny wrapper over one Keychain generic-password item: the Notion token.
///
/// Nothing here ever touches `UserDefaults` or disk in plaintext.
enum KeychainStore {

    private static let service = "app.arque.peekado"
    private static let account = "notion-integration-token"

    static func saveToken(_ token: String) {
        let data = Data(token.utf8)

        // `SecItemAdd` fails on a duplicate, so clear any existing item first.
        SecItemDelete(baseQuery() as CFDictionary)

        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func readToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty
        else { return nil }

        return token
    }

    static func deleteToken() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
