//
//  AuthenticationManager.swift
//  BLS Event Tracker
//
//  Handles both mock (useMockData=true) and Firebase Auth (useMockData=false).
//  The rest of the app only sees AuthenticationManager — the backend is transparent.
//

import Foundation
import Combine
import UIKit
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

// Thin wrapper so the rest of the app doesn't import FirebaseAuth directly.
// In mock mode this is populated from hardcoded values; in Firebase mode it
// wraps a real FirebaseAuth.User.
class AppUser {
    let uid: String
    let email: String?
    let displayName: String?

    init(uid: String, email: String?, displayName: String?) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
    }

    // Convenience init from a Firebase Auth user
    init(_ firebaseUser: FirebaseAuth.User) {
        self.uid = firebaseUser.uid
        self.email = firebaseUser.email
        self.displayName = firebaseUser.displayName
    }
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: AppUser?
    @Published var userProfile: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Set when Google sign-in detects an existing email/password account.
    /// LoginView presents a password prompt so the accounts can be linked.
    @Published var pendingLinkEmail: String?
    @Published var showLinkAccountPrompt = false
    private var pendingGoogleCredential: AuthCredential?

    /// Nonce used to validate the Apple ID token — generated fresh for each sign-in attempt.
    private var currentAppleNonce: String?

    static let shared = AuthenticationManager()

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        if useMockData {
            autoLoginMockUser()
        } else {
            listenToFirebaseAuthState()
        }
    }

    // MARK: - Mock mode

    private func autoLoginMockUser() {
        let mockUser = AppUser(uid: "mock-user-123", email: "test@example.com", displayName: "Test User")
        self.user = mockUser
        self.isAuthenticated = true
        self.userProfile = UserProfile(
            id: mockUser.uid,
            email: mockUser.email,
            displayName: mockUser.displayName,
            communityID: "mock-community-1",
            role: .general,
            address: nil,
            phoneNumber: nil,
            createdAt: Date(),
            lastActiveAt: Date(),
            isActive: true,
            isBanned: false,
            banReason: nil,
            reportCount: 0,
            verificationCount: 0,
            confirmedReportCount: 0,
            confirmedReportPoints: 0
        )
    }

    // MARK: - Firebase Auth state listener

    private func listenToFirebaseAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let firebaseUser {
                    let appUser = AppUser(firebaseUser)
                    self.user = appUser
                    // Don't set isAuthenticated until profile is loaded —
                    // this prevents the map from loading before communityID is available.
                    await self.loadOrCreateUserProfile(for: appUser)
                    // Only mark authenticated if a valid profile with a communityID was loaded.
                    // If profile loading failed (e.g. community not found in Firestore), keep
                    // the user on the login screen so they can retry rather than landing in a
                    // broken state with a nil communityID.
                    self.isAuthenticated = self.userProfile?.communityID.isEmpty == false
                } else {
                    self.user = nil
                    self.userProfile = nil
                    self.isAuthenticated = false
                }
            }
        }
    }

    private func loadOrCreateUserProfile(for appUser: AppUser) async {
        do {
            // Try to load existing profile
            var profile = try await AppDataService.shared.fetchUserProfile(userID: appUser.uid)

            // Heal profiles that ended up with "unknown" communityID due to a
            // previous Firestore rules issue during account creation.
            if profile.communityID == "unknown" || profile.communityID.isEmpty {
                if let realCommunityID = try? await AppDataService.shared.fetchDefaultCommunityID() {
                    profile.communityID = realCommunityID
                    try? await AppDataService.shared.updateUserProfile(profile)
                }
            }

            self.userProfile = profile
        } catch DataServiceError.userNotFound {
            // First sign-in — create a new profile.
            // Retry fetchDefaultCommunityID with backoff because Firebase Auth tokens
            // can take a moment to propagate to Firestore after account creation,
            // causing the first read to fail with a permission error even though the
            // communities rule only requires request.auth != null.
            let communityID: String
            do {
                communityID = try await fetchDefaultCommunityIDWithRetry()
            } catch {
                print("‼️ fetchDefaultCommunityID failed after retries: \(error)")
                self.errorMessage = "Could not assign community. Please check your internet connection and try again."
                return
            }

            let newProfile = UserProfile(
                id: appUser.uid,
                email: appUser.email,
                displayName: appUser.displayName ?? appUser.email ?? "User",
                communityID: communityID,
                role: .general,
                address: nil,
                phoneNumber: nil,
                createdAt: Date(),
                lastActiveAt: Date(),
                isActive: true,
                isBanned: false,
                banReason: nil,
                reportCount: 0,
                verificationCount: 0,
                confirmedReportCount: 0,
                confirmedReportPoints: 0
            )

            do {
                try await AppDataService.shared.createUserProfile(newProfile)
                self.userProfile = newProfile
            } catch {
                print("‼️ createUserProfile failed: \(error)")
                self.errorMessage = "Could not create your account profile. Please check your internet connection and try again. (\(error.localizedDescription))"
            }
        } catch {
            self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
    }

    /// Attempts to fetch the default community ID, retrying up to 3 times with
    /// increasing delays. This handles the window after account creation where
    /// Firestore may not yet accept the new Auth token.
    private func fetchDefaultCommunityIDWithRetry() async throws -> String {
        let delays: [Duration] = [.seconds(1), .seconds(2), .seconds(3)]
        var lastError: Error?
        for delay in delays {
            do {
                return try await AppDataService.shared.fetchDefaultCommunityID()
            } catch {
                print("⚠️ fetchDefaultCommunityID attempt failed (\(error)), retrying after \(delay)…")
                lastError = error
                try? await Task.sleep(for: delay)
            }
        }
        throw lastError!
    }

    // MARK: - Profile Refresh

    /// Re-fetches the current user's profile from the data service and updates the published value.
    /// Call this after any operation that modifies profile stats (submit report, verify, dispute).
    func refreshUserProfile() async {
        guard let userID = user?.uid else { return }
        if let updated = try? await AppDataService.shared.fetchUserProfile(userID: userID) {
            userProfile = updated
        }
    }

    // MARK: - Sign In / Sign Up

    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        if useMockData {
            try await Task.sleep(for: .seconds(1))
            autoLoginMockUser()
        } else {
            do {
                try await Auth.auth().signIn(withEmail: email, password: password)
                // Auth state listener handles the rest
            } catch {
                errorMessage = error.localizedDescription
                throw error
            }
        }
    }

    func signUpWithEmail(email: String, password: String, displayName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        if useMockData {
            try await Task.sleep(for: .seconds(1))
            autoLoginMockUser()
        } else {
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                // Set the display name on the Firebase profile
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
                // Reload so the auth state listener fires with the updated displayName,
                // ensuring the provisioned profile uses the name the user entered rather
                // than falling back to their email address.
                try await result.user.reload()
            } catch {
                errorMessage = error.localizedDescription
                throw error
            }
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        guard !useMockData else {
            // Mock mode: just auto-login like email sign-in
            try await Task.sleep(for: .seconds(1))
            autoLoginMockUser()
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        // Find the topmost presented view controller to present the Google sign-in sheet
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = windowScene.keyWindow?.rootViewController else {
            errorMessage = "Could not find root view controller"
            throw AuthError.invalidCredential
        }
        // Walk up to the topmost presented controller so the sheet isn't blocked
        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidToken
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            do {
                try await Auth.auth().signIn(with: credential)
                // Auth state listener handles profile creation/loading
            } catch let error as NSError
                where error.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
                // An account with this email already exists under a different provider
                // (e.g. email/password). Link the Google credential to that existing account
                // so the user keeps their existing UID, role, and data.
                guard let email = result.user.profile?.email else { throw error }
                try await linkGoogleCredential(credential, toExistingAccountWithEmail: email)
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Stores the Google credential and raises a flag so LoginView can prompt for the password
    /// needed to link the two providers under the existing UID.
    private func linkGoogleCredential(_ googleCredential: AuthCredential, toExistingAccountWithEmail email: String) async throws {
        pendingGoogleCredential = googleCredential
        pendingLinkEmail = email
        showLinkAccountPrompt = true
    }

    /// Called from the link-account prompt after the user enters their password.
    /// Signs in with email/password, links the stored Google credential, then clears state.
    func confirmLinkWithPassword(_ password: String) async throws {
        guard let email = pendingLinkEmail,
              let googleCredential = pendingGoogleCredential else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Sign in with the existing email/password account
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            // Link the Google credential so both providers work going forward
            try await result.user.link(with: googleCredential)
            // Auth state listener updates user/profile as normal
            pendingGoogleCredential = nil
            pendingLinkEmail = nil
            showLinkAccountPrompt = false
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Apple Sign-In

    func signInWithApple() async throws {
        guard !useMockData else {
            try await Task.sleep(for: .seconds(1))
            autoLoginMockUser()
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        // Generate a cryptographic nonce to prevent replay attacks.
        // The SHA-256 hash is sent to Apple; the raw value is verified against
        // the token we receive back.
        let nonce = randomNonce()
        currentAppleNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        // Bridge the delegate-based Apple API to async/await via a continuation.
        let credential: OAuthCredential = try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInDelegate(nonce: nonce, continuation: continuation)
            // Retain the delegate for the duration of the presentation
            self.appleSignInDelegate = delegate

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
        self.appleSignInDelegate = nil

        do {
            try await Auth.auth().signIn(with: credential)
            // Auth state listener handles profile creation/loading
        } catch let error as NSError
            where error.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
            // An email/password account exists for this Apple ID email.
            // Reuse the existing Google linking flow — same prompt, same result.
            if let email = error.userInfo[AuthErrorUserInfoEmailKey] as? String {
                try await linkAppleCredential(credential, toExistingAccountWithEmail: email)
            } else {
                errorMessage = error.localizedDescription
                throw error
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Retains the Apple sign-in delegate for the duration of the ASAuthorizationController presentation.
    private var appleSignInDelegate: AppleSignInDelegate?

    private func linkAppleCredential(_ appleCredential: AuthCredential, toExistingAccountWithEmail email: String) async throws {
        pendingGoogleCredential = appleCredential   // reuse the same pending slot
        pendingLinkEmail = email
        showLinkAccountPrompt = true
    }

    // MARK: - Nonce helpers (required by Apple for secure token validation)

    private func randomNonce(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Sign Out

    func signOut() throws {
        if useMockData {
            user = nil
            userProfile = nil
            isAuthenticated = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.autoLoginMockUser()
            }
        } else {
            try Auth.auth().signOut()
            // Auth state listener sets isAuthenticated = false
        }
    }

    // MARK: - Delete Account

    /// Deletes the user's Firestore profile document and Firebase Auth account,
    /// then clears local auth state. Firebase requires a recent sign-in to delete
    /// an account; if the credential is stale this will throw an error that the
    /// caller should surface to the user.
    func deleteAccount() async throws {
        guard !useMockData else {
            user = nil
            userProfile = nil
            isAuthenticated = false
            return
        }
        guard let firebaseUser = Auth.auth().currentUser,
              let userID = user?.uid else {
            throw AuthError.invalidCredential
        }
        // Delete Firestore profile first so Firestore security rules still
        // allow the write while the Auth account exists.
        try await AppDataService.shared.deleteUserProfile(userID: userID)
        // Delete the Firebase Auth account.
        try await firebaseUser.delete()
        // Auth state listener will fire and clear isAuthenticated,
        // but clear local state immediately for a responsive UI.
        user = nil
        userProfile = nil
        isAuthenticated = false
    }
}

// MARK: - Apple Sign-In Delegate

/// Bridges ASAuthorizationController's delegate callbacks to async/await.
/// The nonce must match what was sent in the request — Apple uses it to
/// prevent replay attacks on the returned identity token.
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let nonce: String
    private let continuation: CheckedContinuation<OAuthCredential, Error>

    init(nonce: String, continuation: CheckedContinuation<OAuthCredential, Error>) {
        self.nonce = nonce
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleIDCredential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            continuation.resume(throwing: AuthError.invalidToken)
            return
        }

        // Apple only provides the full name on the very first sign-in.
        // We pass it directly to OAuthProvider so Firebase can store it on the auth profile;
        // subsequent sign-ins return nil components which Firebase handles gracefully.
        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        continuation.resume(returning: credential)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window for the active scene
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        return scene?.keyWindow ?? UIWindow()
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case invalidToken
    case noCommunityAvailable

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid authentication credential"
        case .invalidToken: return "Failed to obtain authentication token"
        case .noCommunityAvailable: return "No community available for registration"
        }
    }
}
