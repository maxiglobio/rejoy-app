import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var startTime: Date?
    private let particleCount = 25

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard let start = startTime else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let x = size.width / 2 + p.offsetX + p.vx * elapsed
                    let y = size.height / 2 + p.offsetY + p.vy * elapsed
                    let opacity = max(0, 1 - elapsed / 2)
                    var ctx = context
                    ctx.opacity = opacity
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                        with: .color(p.color)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startTime = Date()
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
