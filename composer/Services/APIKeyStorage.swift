//
//  APIKeyStorage.swift
//  composer
//
//  Secure API key storage using Keychain
//

import Foundation
import Security

/// Secure storage for API keys using the system Keychain
actor APIKeyStorage {
    static let shared = APIKeyStorage()

    private let service = "com.composer.apikeys"

    private init() {}

    /// Store an API key for a provider
    func setKey(_ key: String, for provider: String) throws {
        let account = provider
        let keyData = Data(key.utf8)

        // Delete existing key if present
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore(status)
        }
    }

    /// Retrieve an API key for a provider
    func getKey(for provider: String) -> String? {
        let account = provider

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Delete an API key for a provider
    func deleteKey(for provider: String) throws {
        let account = provider

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }

    /// Check if a key exists for a provider
    func hasKey(for provider: String) -> Bool {
        getKey(for: provider) != nil
    }
}

/// Keychain errors
enum KeychainError: Error, LocalizedError {
    case unableToStore(OSStatus)
    case unableToDelete(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unableToStore(let status):
            return "Unable to store key in Keychain: \(status)"
        case .unableToDelete(let status):
            return "Unable to delete key from Keychain: \(status)"
        }
    }
}
