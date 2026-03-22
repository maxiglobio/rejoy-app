import SwiftUI

struct DedicationRitualView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    @State private var message: String
    @State private var showConfetti = false
    let onComplete: (String) -> Void

    init(onComplete: @escaping (String) -> Void) {
        self.onComplete = onComplete
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        _message = State(initialValue: L.string("dedication_default", language: lang))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 24) {
                    TextField(L.string("type_dedication", language: appLanguage), text: $message, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .padding()

                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showConfetti = true
                        onComplete(message)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    } label: {
                        Text("Rejoice")
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
            .navigationTitle("Dedication Ritual")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    private let particleCount = 25

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let x = size.width / 2 + p.offsetX + p.vx * now
                    let y = size.height / 2 + p.offsetY + p.vy * now
                    let opacity = max(0, 1 - now / 2)
                    var ctx = context
                    ctx.opacity = opacity
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                        with: .color(p.color)
                    )
                }
            }
        }
        .onAppear {
            let colors: [Color] = [AppColors.rejoyOrange, AppColors.rejoyOrange.opacity(0.8), Color(white: 0.3), Color(white: 0.5), Color(white: 0.7)]
            particles = (0..<particleCount).map { _ in
                ConfettiParticle(
                    offsetX: .random(in: -50...50),
                    offsetY: .random(in: -50...50),
                    vx: .random(in: -100...100),
                    vy: .random(in: -150...(-50)),
                    color: colors.randomElement()!
                )
            }
        }
    }
}

struct ConfettiParticle {
    let offsetX: Double
    let offsetY: Double
    let vx: Double
    let vy: Double
    let color: Color
}
