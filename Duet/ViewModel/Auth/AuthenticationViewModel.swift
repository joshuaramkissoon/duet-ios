//
//  AuthenticationViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 19/05/2025.
//

import Foundation
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
class AuthenticationViewModel: ObservableObject {
    enum State {
        case unauthenticated, authenticating, authenticated
    }

    @Published var state: State = .unauthenticated
    @Published var errorMessage: String?
    @Published var user: FirebaseAuth.User? {
        didSet { handleNewUser(oldValue: oldValue, newValue: user) }
    }
    @Published var isSigningInAnonymously = false
    
    private var currentNonce: String?
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.user = user
            self.state = (user == nil ? .unauthenticated : .authenticated)
        }
    }

    deinit {
        if let h = handle { Auth.auth().removeStateDidChangeListener(h) }
    }
    
    private func handleNewUser(oldValue: FirebaseAuth.User?, newValue: FirebaseAuth.User?) {
        guard
            let user = newValue,
            oldValue?.uid != user.uid
        else { return }
        
        createRemoteUserRecord(for: user)
    }
    
    private func createRemoteUserRecord(for user: FirebaseAuth.User) {
        let name  = user.displayName
        
        NetworkClient.shared.createUser(user: User(id: user.uid, name: name)) { result in
            switch result {
            case .success:
                print("🟢 Remote user record created for \(user.uid)")
            case .failure(let err):
                DispatchQueue.main.async {
                    self.state = .unauthenticated
                    self.errorMessage = "Failed to create user"
                }
            }
        }
    }
    
    func signOut() {
        do { try Auth.auth().signOut() }
        catch { errorMessage = error.localizedDescription }
    }
    
    func signInAnonymously() {
        isSigningInAnonymously = true
        Auth.auth().signInAnonymously { [weak self] res, err in
            DispatchQueue.main.async { self?.isSigningInAnonymously = false }
            if let err = err { self?.errorMessage = err.localizedDescription }
        }
    }
    
    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
    }
    
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let err):
            errorMessage = err.localizedDescription
            
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce
            else {
                errorMessage = "Apple sign in failed"
                return
            }
            let cred = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            Task {
                do {
                    try await Auth.auth().signIn(with: cred)
                }
                catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: — Helpers for Apple nonce

fileprivate func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length
    while remaining > 0 {
        let randoms = (0..<16).compactMap { _ -> UInt8? in
            var b: UInt8 = 0
            return SecRandomCopyBytes(kSecRandomDefault, 1, &b) == errSecSuccess ? b : nil
        }
        randoms.forEach { b in
            if remaining > 0, Int(b) < charset.count {
                result.append(charset[Int(b)])
                remaining -= 1
            }
        }
    }
    return result
}

fileprivate func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}

