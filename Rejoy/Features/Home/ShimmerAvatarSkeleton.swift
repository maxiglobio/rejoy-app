import SwiftUI

/// Avatar loading placeholder: same ring layout as `SanghaAvatarStrip`, neutral fill, horizontal shimmer sweep (common iOS / modern-app pattern).
struct ShimmerAvatarSkeleton: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let innerSize: CGFloat = 67
    private let outerRingWidth: CGFloat = 2.5
    private let innerRingWidth: CGFloat = 1

    /// One full left → right sweep.
    private let sweepPeriod: TimeInterval = 1.65

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor, lineWidth: outerRingWidth)
                .frame(width: size, height: size)
            Circle()
                .stroke(Color.white, lineWidth: innerRingWidth)
                .frame(width: innerSize, height: innerSize)
            innerDisk
        }
    }

    private var ringColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color(.systemGray4).opacity(0.55)
    }

    @ViewBuilder
    private var innerDisk: some View {
        if accessibilityReduceMotion {
            Circle()
                .fill(Color(.secondarySystemFill))
                .frame(width: innerSize, height: innerSize)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = (t.truncatingRemainder(dividingBy: sweepPeriod)) / sweepPeriod
                let travel = innerSize * 1.2
                let offsetX = CGFloat(phase * 2 - 1) * travel * 0.5

                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemFill))
                        .frame(width: innerSize, height: innerSize)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(shimmerHighlightOpacity),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: innerSize * 0.68, height: innerSize * 1.02)
                    .offset(x: offsetX)
                    .blendMode(.overlay)
                }
                .frame(width: innerSize, height: innerSize)
                .clipShape(Circle())
            }
        }
    }

    private var shimmerHighlightOpacity: Double {
        colorScheme == .dark ? 0.26 : 0.34
    }
}
