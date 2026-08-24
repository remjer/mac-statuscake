import Foundation
import Security
import StatusCakeCore

/// The only place this app touches the Keychain. A plain generic-password
/// item, one fixed service/account pair -- there is exactly one StatusCake
/// token per user, so there is nothing to key it by.
enum KeychainTokenStore {
    private static let service = "com.communicatie-cockpit.mac-statuscake"
    private static let account = "statuscake-api-token"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    /// Updates the item if one exists, otherwise adds it -- callers never
    /// need to know which case they are in.
    @discardableResult
    static func save(_ token: String) -> Bool {
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let data = Data(token.utf8)

        let updateStatus = SecItemUpdate(identity as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var addAttributes = identity
        addAttributes[kSecValueData as String] = data
        addAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(addAttributes as CFDictionary, nil) == errSecSuccess
    }

    /// Deleting an item that is not there is not a failure -- the end state
    /// the caller wants (no token in the Keychain) is already true.
    @discardableResult
    static func remove() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

/// Slots into `resolveToken(from:)` alongside `EnvironmentTokenSource`
/// without any call site in `StatusCakeCore` changing -- exactly what the
/// `TokenSource` protocol was built for in phase 1.
struct KeychainTokenSource: TokenSource {
    let sourceKind: TokenStatus.Source = .keychain
    func token() -> String? {
        KeychainTokenStore.read()
    }
}
