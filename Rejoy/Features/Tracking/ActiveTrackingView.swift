import ActivityKit
import SwiftUI
import UIKit

struct ActiveTrackingView: View {
    @ObservedObject var session: ActiveTrackingSession
    @Binding var isCollapsed: Bool
    let onStop: (Int) -> Void

    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var liveActivity: Activity<RejoyTrackingAttributes>?
    @State private var iconScale: CGFloat = 1.0

    var body: some View {
        Group {
            if isCollapsed {
                compactBar
            } else {
                expandedView
            }
        }
        .onAppear {
            if session.isPaused {
                session.stopTimer()
            } else {
                session.startTimer()
            }
            session.persistState()
            session.onSignificantTimingChange = { syncLiveActivityState() }
            startLiveActivity()
        }
        .onDisappear {
            session.onSignificantTimingChange = nil
        }
        /// Per-second push refreshes `seedsSnapshot` in Live Activity state (SwiftUI `Text` only — UIKit is not supported there).
        /// System `Text(timerInterval:)` advances time without this.
        .onChange(of: session.elapsedSeconds) { _, _ in
            syncLiveActivityState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, !session.isPaused {
                session.elapsedSeconds = session.totalPausedSeconds + Int(Date().timeIntervalSince(session.startDate))
                syncLiveActivityState()
            }
        }
        .task(id: session.isPaused) {
            guard !session.isPaused else {
                iconScale = 1.0
                return
            }
            while true {
                // Icon pulse: softly scale up and down each second (when active)
                withAnimation(.easeInOut(duration: 0.5)) {
                    iconScale = 1.1
                }
                try? await Task.sleep(for: .seconds(0.5))
                guard !session.isPaused else { break }
                withAnimation(.easeInOut(duration: 0.5)) {
                    iconScale = 1.0
                }
                try? await Task.sleep(for: .seconds(0.5))
                guard !session.isPaused else { break }
            }
            iconScale = 1.0
        }
    }

    private var expandedView: some View {
        VStack(spacing: 32) {
            HStack {
                Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isCollapsed = true
            } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(AppFont.title2)
                        .foregroundStyle(AppColors.dotsSecondaryText)
                }
                .padding(.trailing, 20)
                .padding(.top, 8)
            }

            Text(L.activityName(session.activity.name, language: appLanguage))
                .font(AppFont.title2)
                .fontWeight(.semibold)

            Image(systemName: session.activity.symbolName)
                .font(AppFont.rounded(size: 48))
                .foregroundStyle(AppColors.rejoyOrange)
                .scaleEffect(iconScale)

            Text(session.formattedTime(session.displayedSeconds))
                .font(AppFont.rounded(size: 56, weight: .light))

            Text(String(format: L.string("seeds_planted_count", language: appLanguage), session.seeds))
                .font(AppFont.title3)
                .foregroundStyle(AppColors.dotsSecondaryText)

            Spacer()

            HStack(spacing: 24) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if session.isPaused {
                        session.resumeTimer()
                    } else {
                        session.pauseTimer()
                    }
                } label: {
                    Label(session.isPaused ? L.string("resume", language: appLanguage) : L.string("pause", language: appLanguage), systemImage: session.isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)

                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    stopAndDismiss()
                } label: {
                    Label(L.string("stop", language: appLanguage), systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.rejoyOrange)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var compactBar: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .allowsHitTesting(false)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isCollapsed = false
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: session.activity.symbolName)
                        .font(AppFont.title2)
                        .foregroundStyle(AppColors.rejoyOrange)
                        .scaleEffect(iconScale)
                        .frame(width: 36, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.activityName(session.activity.name, language: appLanguage))
                            .font(AppFont.headline)
                            .foregroundStyle(.primary)
                        Text("\(session.formattedTime(session.displayedSeconds)) · \(String(format: L.string("seeds_count", language: appLanguage), session.seeds))")
                            .font(AppFont.subheadline)
                            .foregroundStyle(AppColors.dotsStatsText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.circle.fill")
                        .font(AppFont.title3)
                        .foregroundStyle(AppColors.dotsSecondaryText)
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    compactBarBorderStroke
                }
                .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 64)
        }
    }

    /// Collapsed bar border: slow rotating orange highlight while tracking; static when paused or Reduce Motion.
    @ViewBuilder
    private var compactBarBorderStroke: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        if accessibilityReduceMotion || session.isPaused {
            shape.strokeBorder(compactBarStaticBorderGradient, lineWidth: 1)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let r = (t * 56.0).truncatingRemainder(dividingBy: 360)
                shape.strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            AppColors.rejoyOrange.opacity(0.1),
                            AppColors.rejoyOrange.opacity(0.4),
                            AppColors.rejoyOrange.opacity(0.95),
                            AppColors.rejoyOrange.opacity(0.4),
                            AppColors.rejoyOrange.opacity(0.1)
                        ]),
                        center: .center,
                        startAngle: .degrees(r),
                        endAngle: .degrees(r + 360)
                    ),
                    lineWidth: 1.25
                )
            }
        }
    }

    private var compactBarStaticBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.38),
                Color.white.opacity(0.1),
                AppColors.rejoyOrange.opacity(0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func stopAndDismiss() {
        session.stopTimer()
        endLiveActivity()
        ActiveTrackingPersistence.clear()
        onStop(session.effectiveElapsedSeconds())
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = RejoyTrackingAttributes(
            activityName: session.activity.name,
            symbolName: session.activity.symbolName
        )
        let state = liveActivityContentState()
        Task {
            for existing in Activity<RejoyTrackingAttributes>.activities {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            let activity = try? Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            await MainActor.run {
                liveActivity = activity
            }
        }
    }

    private func liveActivityContentState() -> RejoyTrackingAttributes.ContentState {
        RejoyTrackingAttributes.ContentState(
            accumulatedSeconds: session.totalPausedSeconds,
            segmentStartDate: session.startDate,
            isPaused: session.isPaused,
            seedsPerSecond: AppSettings.seedsPerSecond,
            seedsSnapshot: session.seeds
        )
    }

    private func syncLiveActivityState() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = liveActivityContentState()
        Task {
            for existing in Activity<RejoyTrackingAttributes>.activities {
                try? await existing.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    private func endLiveActivity() {
        liveActivity = nil
        Task {
            for existing in Activity<RejoyTrackingAttributes>.activities {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
