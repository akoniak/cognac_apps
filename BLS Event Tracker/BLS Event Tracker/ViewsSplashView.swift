//
//  SplashView.swift
//  BLS Event Tracker
//
//  Shown on launch while Firebase resolves the user's auth state,
//  preventing the login screen from flashing for already-logged-in users.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("BearIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)

                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }
}

#Preview {
    SplashView()
}
