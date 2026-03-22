import SwiftUI
import UIKit

/// Rounded hexagon shape matching Figma badge design (flat-top, 6 sides).
private struct RoundedHexagonShape: Shape {
    var cornerRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angleOffset = -CGFloat.pi / 2 // flat top

        // Clamp corner radius to max ~1/3 of edge length
        let edgeLength = 2 * radius * sin(.pi / 6)
        let r = min(cornerRadius, edgeLength * 0.4)

        for i in 0..<6 {
            let angleA = angleOffset + CGFloat(i) * CGFloat.pi / 3
            let angleB = angleOffset + CGFloat(i + 1) * CGFloat.pi / 3

            let vertex = CGPoint(
                x: center.x + cos(angleA) * radius,
                y: center.y + sin(angleA) * radius
            )
            let nextVertex = CGPoint(
                x: center.x + cos(angleB) * radius,
                y: center.y + sin(angleB) * radius
            )
            let prevAngle = angleOffset + CGFloat(i - 1) * CGFloat.pi / 3
            let prevVertex = CGPoint(
                x: center.x + cos(prevAngle) * radius,
                y: center.y + sin(prevAngle) * radius
            )

            // Point before vertex (along edge from prev)
            let distPrev = hypot(vertex.x - prevVertex.x, vertex.y - prevVertex.y)
            let tPrev = r / distPrev
            let beforeVertex = CGPoint(
                x: vertex.x - (vertex.x - prevVertex.x) * tPrev,
                y: vertex.y - (vertex.y - prevVertex.y) * tPrev
            )
            // Point after vertex (along edge to next)
            let distNext = hypot(nextVertex.x - vertex.x, nextVertex.y - vertex.y)
            let tNext = r / distNext
            let afterVertex = CGPoint(
                x: vertex.x + (nextVertex.x - vertex.x) * tNext,
                y: vertex.y + (nextVertex.y - vertex.y) * tNext
            )

            if i == 0 {
                path.move(to: beforeVertex)
            } else {
                path.addLine(to: beforeVertex)
            }
            path.addArc(
                tangent1End: vertex,
                tangent2End: afterVertex,
                radius: r
            )
        }
        path.closeSubpath()
        return path
    }
}

struct AchievementBadgeView: View {
    let achievement: Achievement
    var count: Int = 1
    var showTitle: Bool = true
    var size: CGFloat = 86
    var shimmer: Bool = false
    /// Muted grey hex and dim symbol (no orange); use for locked catalog items.
    var isLocked: Bool = false
    @Environment(\.appLanguage) private var appLanguage
    @State private var shimmerPhase: CGFloat = 0
    @State private var shimmerTimer: Timer?
    private let badgeGradient = LinearGradient(
        colors: [
            Color(red: 1, green: 0.8, blue: 0.63),   // #ffcba1
            AppColors.rejoyOrange
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    private let iconGradient = LinearGradient(
        colors: [
            Color(red: 0.82, green: 0.37, blue: 0.008),  // #d15f02
            Color(red: 1, green: 0.45, blue: 0.008)      // #fe7302
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    private let lockedBadgeFill = LinearGradient(
        colors: [
            Color(uiColor: .systemGray4),
            Color(uiColor: .systemGray3)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private var iconFontSize: CGFloat { size * 32 / 86 }

    /// Invalid or OS-missing SF Symbol names render empty; fall back so cells always show an icon.
    private var resolvedSymbolName: String {
        let name = achievement.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, UIImage(systemName: name) != nil else {
            return "star.fill"
        }
        return name
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedHexagonShape()
                    .fill(isLocked ? lockedBadgeFill : badgeGradient)
                    .frame(width: size, height: size)

                RoundedHexagonShape()
                    .stroke(isLocked ? Color.secondary.opacity(0.35) : Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: size, height: size)

                Image(systemName: resolvedSymbolName)
                    .font(AppFont.rounded(size: iconFontSize, weight: .semibold))
                    .foregroundStyle(isLocked ? AnyShapeStyle(Color.secondary.opacity(0.45)) : AnyShapeStyle(iconGradient))
                    .shadow(color: isLocked ? .clear : Color.white.opacity(0.25), radius: 4, x: 0, y: 3)
                    .symbolRenderingMode(.monochrome)
            }
            .overlay {
                if shimmer, !isLocked {
                    RoundedHexagonShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .clear, location: max(0, shimmerPhase - 0.12)),
                                    .init(color: Color.white.opacity(0.75), location: shimmerPhase),
                                    .init(color: .clear, location: min(1, shimmerPhase + 0.12)),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size, height: size)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                if shimmer, !isLocked {
                    let fire: () -> Void = {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            shimmerPhase = 1
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            shimmerPhase = 0
                        }
                    }
                    fire()
                    shimmerTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                        fire()
                    }
                    RunLoop.main.add(shimmerTimer!, forMode: .common)
                }
            }
            .onDisappear {
                shimmerTimer?.invalidate()
                shimmerTimer = nil
            }
            .overlay(alignment: .topTrailing) {
                if !isLocked, count > 1 {
                    Text("x\(count)")
                        .font(AppFont.rounded(size: 12, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
                        .offset(x: 4, y: 4)
                }
            }
            .shadow(
                color: isLocked ? Color.black.opacity(0.06) : Color(red: 1, green: 0.47, blue: 0.043).opacity(0.2),
                radius: isLocked ? 2 : 4,
                x: 0,
                y: isLocked ? 2 : 4
            )

            if showTitle {
                Text(achievement.title(for: appLanguage))
                    .font(AppFont.caption)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(width: showTitle ? 96 : size + 12)
    }
}
