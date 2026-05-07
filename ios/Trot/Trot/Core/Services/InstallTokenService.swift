import Foundation
import Security

/// Persistent anonymous install token. Minted on first need, stored in
/// `UserDefaults`, sent with every LLM proxy request so the proxy can
/// rate-limit per install without ever seeing user identity.
///
/// Not a credential — leaking it has no consequences beyond someone else
/// being able to spend rate-limit quota in our name. UserDefaults is
/// adequate; a Keychain upgrade is a one-line swap if ever needed.
enum InstallTokenService {
    private static let key = "trot.installToken"

    /// Return the existing token if one exists; mint and persist a new one
    /// on first call.
    static func token() -> String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let fresh = mint()
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    private static func mint() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let result = bytes.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, base)
        }
        if result == errSecSuccess {
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
        // Vanishingly unlikely fallback — UUID is good enough as a token.
        return UUID().uuidString
    }
}
