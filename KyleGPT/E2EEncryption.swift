import Foundation
import CryptoKit
import Security

// MARK: - E2E ENCRYPTION MANAGER

class CryptoManager {
    static let shared = CryptoManager()
    
    private let privateKeyTag = "com.kylegpt.e2ee.privatekey"
    private var cachedPrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var sharedSecrets: [String: SymmetricKey] = [:] // email -> shared secret
    
    // MARK: - Key Generation & Storage
    
    /// Generate a new Curve25519 keypair, store private key in Keychain
    func generateKeyPairIfNeeded() {
        if loadPrivateKey() != nil { return } // Already have one
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        savePrivateKey(privateKey)
        cachedPrivateKey = privateKey
        print("🔐 E2EE: Generated new keypair")
    }
    
    /// Returns the public key as a Base64 string for sharing with the server
    func getPublicKeyBase64() -> String? {
        guard let privateKey = getPrivateKey() else { return nil }
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
    }
    
    /// Get the private key (cached or from Keychain)
    private func getPrivateKey() -> Curve25519.KeyAgreement.PrivateKey? {
        if let cached = cachedPrivateKey { return cached }
        let key = loadPrivateKey()
        cachedPrivateKey = key
        return key
    }
    
    // MARK: - Keychain Operations
    
    private func savePrivateKey(_ key: Curve25519.KeyAgreement.PrivateKey) {
        let keyData = key.rawRepresentation
        
        // Delete any existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: privateKeyTag
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: privateKeyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ E2EE: Failed to save private key: \(status)")
        }
    }
    
    private func loadPrivateKey() -> Curve25519.KeyAgreement.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: privateKeyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let keyData = item as? Data else { return nil }
        return try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
    }
    
    /// Delete the private key (used on account deletion / logout)
    func deleteKeyPair() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: privateKeyTag
        ]
        SecItemDelete(query as CFDictionary)
        cachedPrivateKey = nil
        sharedSecrets.removeAll()
        print("🗑️ E2EE: Keypair deleted")
    }
    
    // MARK: - ECDH Shared Secret
    
    /// Derive a shared secret from a peer's public key (Base64-encoded)
    func deriveSharedSecret(peerPublicKeyBase64: String, forEmail email: String) -> Bool {
        guard let privateKey = getPrivateKey(),
              let peerKeyData = Data(base64Encoded: peerPublicKeyBase64),
              let peerPublicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerKeyData) else {
            print("⚠️ E2EE: Failed to derive shared secret for \(email)")
            return false
        }
        
        guard let sharedSecret = try? privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey) else {
            print("⚠️ E2EE: ECDH failed for \(email)")
            return false
        }
        
        // Derive a symmetric key using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: "kylegpt-e2ee-v1".data(using: .utf8)!,
            sharedInfo: Data(),
            outputByteCount: 32
        )
        
        sharedSecrets[email] = symmetricKey
        print("🔐 E2EE: Shared secret derived for \(email)")
        return true
    }
    
    /// Check if we have a shared secret for a peer
    func hasSharedSecret(forEmail email: String) -> Bool {
        return sharedSecrets[email] != nil
    }
    
    // MARK: - AES-256-GCM Encryption
    
    /// Encrypt a string. Returns Base64-encoded (nonce + ciphertext + tag).
    /// Returns nil if no shared secret exists for the peer.
    func encrypt(_ plaintext: String, forPeer email: String) -> String? {
        guard let key = sharedSecrets[email],
              let data = plaintext.data(using: .utf8) else { return nil }
        
        guard let sealedBox = try? AES.GCM.seal(data, using: key) else { return nil }
        
        // Combined = nonce (12) + ciphertext + tag (16)
        return sealedBox.combined?.base64EncodedString()
    }
    
    /// Decrypt a Base64-encoded sealed box. Returns plaintext string.
    func decrypt(_ base64Ciphertext: String, fromPeer email: String) -> String? {
        guard let key = sharedSecrets[email],
              let combined = Data(base64Encoded: base64Ciphertext) else { return nil }
        
        guard let sealedBox = try? AES.GCM.SealedBox(combined: combined),
              let decryptedData = try? AES.GCM.open(sealedBox, using: key) else { return nil }
        
        return String(data: decryptedData, encoding: .utf8)
    }
    
    /// Encrypt image data (Base64 string). Same approach, just on the raw Base64 bytes.
    func encryptImage(_ imageBase64: String, forPeer email: String) -> String? {
        return encrypt(imageBase64, forPeer: email)
    }
    
    /// Decrypt image data back to Base64 string.
    func decryptImage(_ encryptedBase64: String, fromPeer email: String) -> String? {
        return decrypt(encryptedBase64, fromPeer: email)
    }
    
    // MARK: - Key Exchange via Server
    
    /// Upload our public key to the server
    func uploadPublicKey() {
        guard let pubKey = getPublicKeyBase64(),
              let url = URL(string: "\(AppConfig.serverURL)/keys") else { return }
        
        var request = APIClient.shared.authenticatedRequest(url: url, method: "PUT")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["publicKey": pubKey])
        APIClient.shared.fire(request: request)
        print("📤 E2EE: Public key uploaded")
    }
    
    /// Fetch a peer's public key and derive the shared secret
    func fetchAndDeriveKey(forEmail email: String, completion: @escaping (Bool) -> Void) {
        // Return immediately if we already have the secret
        if hasSharedSecret(forEmail: email) { completion(true); return }
        
        guard let url = URL(string: "\(AppConfig.serverURL)/keys/\(email)") else {
            completion(false); return
        }
        
        let request = APIClient.shared.authenticatedRequest(url: url)
        APIClient.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let peerKey = json["publicKey"] as? String else {
                print("⚠️ E2EE: Could not fetch public key for \(email)")
                completion(false)
                return
            }
            let success = self.deriveSharedSecret(peerPublicKeyBase64: peerKey, forEmail: email)
            completion(success)
        }
    }
}
