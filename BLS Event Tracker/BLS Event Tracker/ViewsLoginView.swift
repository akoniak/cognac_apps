//
//  LoginView.swift
//  BLS Event Tracker
//
//  Shown when useMockData=false and the user is not signed in.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var linkPassword = ""
    @State private var showLinkError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo / title
                VStack(spacing: 8) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                    Text("Blue Lake Springs")
                        .font(.title.bold())
                    Text("Community Status")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 48)

                // Form
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
                .padding(.horizontal)

                // Primary action
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(!canSubmit || authManager.isLoading)

                // Divider
                HStack {
                    Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                    Text("or").font(.footnote).foregroundStyle(.secondary)
                    Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                }
                .padding(.horizontal)

                // Google Sign-In
                Button {
                    Task { await signInWithGoogle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                        Text("Continue with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .disabled(authManager.isLoading)

                // Apple Sign-In
                Button {
                    Task { await signInWithApple() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .font(.title3)
                        Text("Continue with Apple")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .disabled(authManager.isLoading)

                // Toggle between sign in / sign up
                Button {
                    isSignUp.toggle()
                    authManager.errorMessage = nil
                } label: {
                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "New user?")
                            .foregroundStyle(.secondary)
                        Text(isSignUp ? "Sign In" : "Create an Account")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }

                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Sign In Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
                if !isSignUp {
                    Button("Create Account Instead") {
                        isSignUp = true
                        authManager.errorMessage = nil
                    }
                }
            } message: {
                Text(friendlyErrorMessage)
            }
            // Shown when Google sign-in detects an existing email/password account.
            // The user enters their password to link both providers under one account.
            .alert(
                "Connect Google to Existing Account",
                isPresented: $authManager.showLinkAccountPrompt
            ) {
                SecureField("Password", text: $linkPassword)
                Button("Connect Accounts") {
                    Task { await linkAccounts() }
                }
                Button("Cancel", role: .cancel) {
                    authManager.pendingLinkEmail = nil
                    authManager.showLinkAccountPrompt = false
                    linkPassword = ""
                }
            } message: {
                Text("An account already exists for \(authManager.pendingLinkEmail ?? "this email"). Enter your password to connect Google Sign-In to your existing account.")
            }
            .alert("Link Failed", isPresented: $showLinkError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authManager.errorMessage ?? "Incorrect password. Please try again.")
            }
            // Shown when sign-in succeeds but profile/community setup fails
            // (e.g. Firestore community lookup returns no results).
            .alert("Setup Error", isPresented: Binding(
                get: { !showError && !authManager.showLinkAccountPrompt && authManager.errorMessage != nil },
                set: { if !$0 { authManager.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authManager.errorMessage ?? "")
            }
            // When presented as a sheet and login succeeds, dismiss automatically.
            .onChange(of: authManager.isAuthenticated) { _, isAuth in
                if isAuth { dismiss() }
            }
        }
    }

    private var canSubmit: Bool {
        let hasEmail = !email.trimmingCharacters(in: .whitespaces).isEmpty
        let hasPassword = password.count >= 6
        let hasName = !isSignUp || !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        return hasEmail && hasPassword && hasName
    }

    /// Translates raw Firebase error messages into plain English.
    private var friendlyErrorMessage: String {
        let raw = authManager.errorMessage ?? "An error occurred"
        if raw.contains("malformed") || raw.contains("expired") || raw.contains("no user record") {
            return "No account found for that email. Tap \"Create an Account\" to sign up."
        } else if raw.contains("password is invalid") || raw.contains("wrong-password") {
            return "Incorrect password. Please try again."
        } else if raw.contains("email address is already in use") {
            return "An account already exists for that email. Try signing in instead."
        } else if raw.contains("badly formatted") {
            return "Please enter a valid email address."
        } else if raw.contains("network") {
            return "Network error. Check your connection and try again."
        }
        return raw
    }

    private func linkAccounts() async {
        do {
            try await authManager.confirmLinkWithPassword(linkPassword)
            linkPassword = ""
        } catch {
            linkPassword = ""
            showLinkError = true
        }
    }

    private func signInWithGoogle() async {
        do {
            try await authManager.signInWithGoogle()
        } catch {
            showError = true
        }
    }

    private func signInWithApple() async {
        do {
            try await authManager.signInWithApple()
        } catch {
            // ASAuthorizationError.canceled means the user dismissed the sheet — don't show an error
            let asError = error as? ASAuthorizationError
            if asError?.code != .canceled {
                showError = true
            }
        }
    }

    private func submit() async {
        do {
            if isSignUp {
                try await authManager.signUpWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespaces)
                )
            } else {
                try await authManager.signInWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
        } catch {
            showError = true
        }
    }
}

#Preview {
    LoginView()
}
