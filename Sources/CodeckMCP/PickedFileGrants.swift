import Foundation
import LocalAuthentication
import Security

protocol PickedFileGrantStorage {
    func contains(scope: String, path: String) throws -> Bool
    func grant(scope: String, path: String) throws
}

/// Picker approvals are protected by Keychain rather than agent-editable workspace files.
final class PickedFileGrants {
    private let scope: String
    private let storage: any PickedFileGrantStorage

    init(directory: URL, storage: any PickedFileGrantStorage = KeychainFileGrantStorage()) {
        scope = PathAccessGuard.canonicalURLPreservingMissingPath(directory).path
        self.storage = storage
    }

    func contains(_ path: String) -> Bool {
        // Unavailable, locked, or unauthorized Keychain access must fail closed.
        (try? storage.contains(scope: scope, path: path)) == true
    }

    func grant(_ path: String) throws {
        try storage.grant(scope: scope, path: path)
    }
}

struct KeychainFileGrantStorage: PickedFileGrantStorage {
    func contains(scope: String, path: String) throws -> Bool {
        var query = try query(scope: scope, path: path)
        // Read the protected value, not publicly queryable item attributes.
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return false }
        try check(status)
        return (result as? Data) == Data(path.utf8)
    }

    func grant(scope: String, path: String) throws {
        if try contains(scope: scope, path: path) { return }
        var item = try query(scope: scope, path: path)
        item[kSecAttrLabel as String] = "Codeck selected file"
        item[kSecValueData as String] = Data(path.utf8)
        // Each file is a separate item, so concurrent helpers cannot lose another grant.
        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem, try contains(scope: scope, path: path) { return }
        try check(status)
    }

    private func query(scope: String, path: String) throws -> [String: Any] {
        let account = try JSONEncoder().encode([scope, path]).base64EncodedString()
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.luku.Codeck.workspace.picked-files",
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw CodeckMCPError.invalidParams("Cannot access Codeck's selected-file permissions in Keychain (\(status)).")
        }
    }
}
