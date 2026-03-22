import Foundation
import AuthenticationServices
import CryptoKit

/// Helper for Sign in with Apple: generates nonce and provides the raw nonce for Supabase verification.
enum AppleSignInHelper {
    static func makeNonce() -> String {
        let raw = UUID().uuidString
        return raw
    }

    /// Returns SHA256 hash of nonce for use in ASAuthorizationAppleIDRequest.
    static func sha256(_ nonce: String) -> String {
        let data = Data(nonce.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
