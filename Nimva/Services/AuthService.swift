import AuthenticationServices
import SwiftUI

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown   // credential check hasn't run yet — show a blank loading screen
    case signedIn  // Apple credential is verified and stored in Keychain
    case anonymous // no Apple ID; user chose to skip or credential was revoked
}

// MARK: - Auth Service

// @MainActor ensures all state mutations happen on the main thread,
// which matters because credentialState comes back on an arbitrary queue.
@Observable
@MainActor
final class AuthService {

    var authState: AuthState = .unknown

    // True if a valid Apple user ID is in Keychain (does not verify it with Apple servers).
    var hasPreviousSignIn: Bool { KeychainHelper.read(key: "appleUserID") != nil }

    var isSignedIn: Bool { authState == .signedIn }

    // MARK: - Credential check (called on every cold launch)

    // Verifies that the stored Apple credential is still authorized.
    // Apple can revoke a credential if the user removes the app from their Apple ID settings.
    func checkCredentialState() async {
        guard let userID = KeychainHelper.read(key: "appleUserID") else {
            // No stored credential — user is anonymous (or first launch)
            authState = .anonymous
            return
        }

        // Wrap the completion-handler API in async/await using a checked continuation.
        // The continuation resumes once the callback fires — safe because Apple guarantees
        // getCredentialState always calls the handler exactly once.
        let state: ASAuthorizationAppleIDProvider.CredentialState = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }

        if state == .authorized {
            authState = .signedIn
        } else {
            // Revoked or not found — clear the stale credential so the user can re-auth from Settings
            KeychainHelper.delete(key: "appleUserID")
            authState = .anonymous
        }
    }

    // MARK: - Sign in

    // Called with the credential Apple hands back after a successful SIWA button tap.
    // Full name and email are only included on the very first sign-in — Apple omits them on
    // subsequent logins, so we persist the name immediately if it's present.
    func handleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        KeychainHelper.save(key: "appleUserID", value: credential.user)

        // Only set the display name if Apple provided one (first sign-in only)
        if let given = credential.fullName?.givenName, !given.isEmpty {
            UserDefaults.standard.set(given, forKey: "displayName")
        }

        authState = .signedIn
    }

    // MARK: - Sign out

    func signOut() {
        KeychainHelper.delete(key: "appleUserID")
        authState = .anonymous
    }
}

// MARK: - Keychain Helper

// Minimal wrapper around Security framework for storing the Apple user ID.
// UserDefaults is intentionally NOT used here — Apple's documentation requires
// the user identifier to be stored in the Keychain.
private enum KeychainHelper {
    private static let service = Bundle.main.bundleIdentifier ?? "com.nimva"

    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data
        ]
        // Delete any existing entry first so SecItemAdd doesn't return errSecDuplicateItem
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
