import SwiftUI

struct SourceRejoyPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    let sourceLabel: String
    let onRejoy: () -> Void

    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 24) {
                    Text(L.string("dedication_default", language: appLanguage))
                        .font(AppFont.body)
                        .multilineTextAlignment(.center)
                        .padding()

                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showConfetti = true
                        onRejoy()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    } label: {
                        Text("Rejoy")
                            .font(AppFont.title2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }

                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(sourceLabel)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
