import SwiftUI
import SpriteKit
import AuthenticationServices

@MainActor
private final class WelcomeParticlesCoordinator: ObservableObject {
    let scene: WelcomeParticlesScene

    init() {
        self.scene = WelcomeParticlesScene(size: CGSize(width: 400, height: 800))
    }

    func updateGravity(x: CGFloat, y: CGFloat) {
        scene.updateGravity(x: x, y: y)
    }
}

struct WelcomeView: View {
    let onContinue: () -> Void
    let onReplayStories: () -> Void
    @Environment(\.appLanguage) private var appLanguage
    @StateObject private var particlesCoordinator = WelcomeParticlesCoordinator()
    @StateObject private var accelerometer = AccelerometerService()
    @State private var isSigningIn = false
    @State private var signInError: String?
    @State private var appleSignInCoordinator: AppleSignInCoordinator?

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            SpriteView(scene: particlesCoordinator.scene, options: [.allowsTransparency])
                .ignoresSafeArea()
                .onAppear { accelerometer.startUpdates() }
                .onDisappear { accelerometer.stopUpdates() }
                .onReceive(accelerometer.$gravity) { g in
                    particlesCoordinator.updateGravity(x: g.x, y: g.y)
                }

            VStack(spacing: 0) {
            // Replay stories — top right
            HStack {
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onReplayStories()
                } label: {
                    Text(L.string("replay_intro", language: appLanguage))
                        .font(AppFont.rounded(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.dotsSecondaryText)
                }
                .padding(.top, 8)
                .padding(.trailing, 20)
            }

            Spacer()

            // Logo
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 140, maxHeight: 140)

            // Rejoy — SF Rounded
            Text(L.string("rejoy", language: appLanguage))
                .font(AppFont.rounded(size: 36, weight: .semibold))
                .padding(.top, 24)

            // Description — same size as onboarding subtitle (20pt)
            Text(L.string("about_description", language: appLanguage))
                .font(AppFont.rounded(size: 20, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .padding(.horizontal, 40)
                .padding(.top, 12)

            Spacer()

            // Login button — bigger and rounded
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                startSignInWithApple()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(AppFont.rounded(size: 20, weight: .semibold))
                    Text(L.string("sign_in_with_apple", language: appLanguage))
                        .font(AppFont.rounded(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.black)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(isSigningIn)
            .padding(.horizontal, 32)

            Text(loginLegalAttributedString)
                .font(AppFont.rounded(size: 13, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .tint(Color.primary)
                .padding(.horizontal, 28)
                .padding(.top, 14)

            if let error = signInError {
                Text(error)
                    .font(AppFont.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }

            Spacer()
                .frame(height: 48)
        }
        }
        .onAppear {
            appleSignInCoordinator = AppleSignInCoordinator(
                onSuccess: {
                    isSigningIn = false
                    signInError = nil
                    onContinue()
                },
                onError: { message in
                    isSigningIn = false
                    signInError = message  // nil when user cancelled
                }
            )
        }
    }

    private func startSignInWithApple() {
        signInError = nil
        isSigningIn = true
        appleSignInCoordinator?.signIn()
    }

    /// Terms & privacy with tappable links (same pattern as Morph-style login disclaimer).
    private var loginLegalAttributedString: AttributedString {
        let template = L.string("login_legal_markdown", language: appLanguage)
        let formatted = String(
            format: template,
            LegalDocumentLinks.terms.absoluteString,
            LegalDocumentLinks.privacy.absoluteString
        )
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let parsed = try? AttributedString(markdown: formatted, options: options) {
            return parsed
        }
        return AttributedString(formatted)
    }
}

// MARK: - Apple Sign In Coordinator

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var currentNonce: String?
    private let onSuccess: () -> Void
    private let onError: (String?) -> Void

    init(onSuccess: @escaping () -> Void, onError: @escaping (String?) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func signIn() {
        let nonce = AppleSignInHelper.makeNonce()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInHelper.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let nonce = currentNonce else {
            onError("Nonce missing")
            return
        }
        Task { @MainActor in
            do {
                try await SupabaseService.shared.signInWithApple(authorization: authorization, nonce: nonce)
                onSuccess()
            } catch {
                onError(error.localizedDescription)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.code == ASAuthorizationError.canceled.rawValue {
            onError(nil) // User cancelled
        } else {
            onError(error.localizedDescription)
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
}
