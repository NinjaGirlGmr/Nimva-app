import SwiftUI
import AuthenticationServices

// Shown once on first launch, before onboarding.
// Either path — sign in or skip — sets hasSeenSignInPrompt so it never appears again.
struct SignInView: View {
    // AuthService lives in the environment, injected from NimvaApp
    @Environment(AuthService.self) private var authService
    @AppStorage("hasSeenSignInPrompt") private var hasSeenSignInPrompt = false

    var body: some View {
        ZStack {
            NimvaColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 36) {
                        emberHeader
                        privacyPoints
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 100)
                    .padding(.bottom, 40)
                }

                actionButtons
            }
        }
    }

    // MARK: - Sections

    private var emberHeader: some View {
        VStack(spacing: 20) {
            // Ember avatar — same warm glow treatment as EnergyZoneCard
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [NimvaColors.amberWarm.opacity(0.55), .clear],
                        center: .center, startRadius: 0, endRadius: 44
                    ))
                    .frame(width: 96, height: 96)
                    .blur(radius: 14)

                Text("🐣")
                    .font(.system(size: 38))
                    .frame(width: 76, height: 76)
                    .background(NimvaColors.surfaceDeep)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(NimvaColors.amberWarm, lineWidth: 2))
            }

            VStack(spacing: 8) {
                Text("Nimva")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(NimvaColors.textPrimary)

                Text("Sign in to sync your schedule\nacross all your devices")
                    .font(.system(size: 15))
                    .foregroundStyle(NimvaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var privacyPoints: some View {
        VStack(spacing: 14) {
            SignInPrivacyRow(
                icon: "lock.shield.fill",
                text: "Your data lives in your private iCloud — Nimva has no servers"
            )
            SignInPrivacyRow(
                icon: "eye.slash.fill",
                text: "We never see your Apple ID email unless you choose to share it"
            )
            SignInPrivacyRow(
                icon: "icloud.fill",
                text: "Sync automatically between iPhone and iPad"
            )
        }
        .padding(16)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            // SignInWithAppleButton is a native Apple component — always use it rather
            // than a custom button so it automatically picks the right label and passes
            // App Store review checks.
            SignInWithAppleButton(.signIn, onRequest: { request in
                // Only request full name — email is optional and unnecessary for MVP
                request.requestedScopes = [.fullName]
            }, onCompletion: { result in
                if case .success(let auth) = result,
                   let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                    authService.handleCredential(credential)
                }
                // Always advance past this screen — even if the user cancelled the sheet
                withAnimation { hasSeenSignInPrompt = true }
            })
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Clearly visible skip — no dark patterns
            Button {
                withAnimation { hasSeenSignInPrompt = true }
            } label: {
                Text("Continue without signing in")
                    .font(.system(size: 14))
                    .foregroundStyle(NimvaColors.textMuted)
            }
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 48)
    }
}

// MARK: - Privacy row

private struct SignInPrivacyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(NimvaColors.teal)
                .frame(width: 22, height: 22)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(NimvaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthService())
}
