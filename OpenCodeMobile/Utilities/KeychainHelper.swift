import Foundation
import Security

// MARK: - KeychainHelper
// iOS Keychain 封装 — 安全存储 opencode 服务器密码

enum KeychainHelper {
    private static let service = "com.opencode.mobile"

    /// 保存密码到 Keychain
    static func save(password: String, account: String = "opencode") {
        let data = password.data(using: .utf8) ?? Data()

        // 先尝试删除旧的
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain 保存失败: \(status)")
        }
    }

    /// 读取密码
    static func load(account: String = "opencode") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    /// 删除密码
    static func delete(account: String = "opencode") {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
