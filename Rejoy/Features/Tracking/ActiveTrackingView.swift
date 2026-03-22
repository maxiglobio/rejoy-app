import ActivityKit
import SwiftUI
import UIKit

struct ActiveTrackingView: View {
    @ObservedObject var session: ActiveTrackingSession
    @Binding var isCollapsed: Bool
    let onStop: (Int) -> Void

    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.scenePhase) private var scenePhase
    @State private var liveActivity: Activity<RejoyTrackingAttributes>?
    @State private var iconScale: CGFloat = 1.0
    @State private var ambientPhase: CGFloat = 0

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
            session.onTick = { updateLiveActivity() }
            startLiveActivity()
        }
        .onDisappear {
            session.stopTimer()
            session.onTick = nil
        }
        .onChange(of: session.elapsedSeconds) { _, _ in updateLiveActivity() }
        .onChange(of: session.isPaused) { _, _ in updateLiveActivity() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, !session.isPaused {
                session.elapsedSeconds = session.totalPausedSeconds + Int(Date().timeIntervalSince(session.startDate))
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
        .task(id: isCollapsed) {
            guard isCollapsed else {
                ambientPhase = 0
                return
            }
            while true {
                try? await Task.sleep(for: .seconds(0.5))
                guard isCollapsed else { break }
                withAnimation(.easeInOut(duration: 2.0)) {
                    ambientPhase = 1
                }
                try? await Task.sleep(for: .seconds(2.0))
                guard isCollapsed else { break }
                withAnimation(.easeInOut(duration: 2.0)) {
                    ambientPhase = 0
                }
                try? await Task.sleep(for: .seconds(0.5))
                guard isCollapsed else { break }
            }
            ambientPhase = 0
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
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppColors.rejoyOrange.opacity(0.04 + 0.06 * ambientPhase),
                                    AppColors.rejoyOrange.opacity((0.04 + 0.06 * ambientPhase) * 0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .blur(radius: 24)
                        .allowsHitTesting(false)
                )
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.dotsActiveRowBorder, lineWidth: 3))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 64)
        }
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
        let state = RejoyTrackingAttributes.ContentState(
            elapsedSeconds: session.displayedSeconds,
            seeds: session.seeds,
            isPaused: session.isPaused
        )
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

    private func updateLiveActivity() {
        let activity = liveActivity
        let state = RejoyTrackingAttributes.ContentState(
            elapsedSeconds: session.displayedSeconds,
            seeds: session.seeds,
            isPaused: session.isPaused
        )
        Task {
            await activity?.update(
                ActivityContent(state: state, staleDate: nil)
            )
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
