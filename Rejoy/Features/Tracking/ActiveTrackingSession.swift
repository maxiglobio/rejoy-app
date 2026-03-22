import Foundation
import SwiftUI

/// Shared state for an active tracking session. Used by ActiveTrackingView and HomeView (timeline).
final class ActiveTrackingSession: ObservableObject, Equatable {
    static func == (lhs: ActiveTrackingSession, rhs: ActiveTrackingSession) -> Bool {
        lhs === rhs
    }
    let activity: ActivityType

    @Published var startDate: Date
    @Published var totalPausedSeconds: Int
    @Published var isPaused: Bool
    @Published var elapsedSeconds: Int

    private var timer: Timer?
    private let seedsPerSecond: Int
    var onTick: (() -> Void)?

    var displayedSeconds: Int { isPaused ? totalPausedSeconds : elapsedSeconds }
    var seeds: Int { displayedSeconds * seedsPerSecond }

    init(activity: ActivityType, startDate: Date, totalPausedSeconds: Int = 0, isPaused: Bool = false) {
        self.activity = activity
        self.startDate = startDate
        self.totalPausedSeconds = totalPausedSeconds
        self.isPaused = isPaused
        self.seedsPerSecond = AppSettings.seedsPerSecond
        self.elapsedSeconds = totalPausedSeconds + (isPaused ? 0 : Int(Date().timeIntervalSince(startDate)))
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if !self.isPaused {
                self.elapsedSeconds = self.totalPausedSeconds + Int(Date().timeIntervalSince(self.startDate))
            }
            self.persistState()
            self.onTick?()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func pauseTimer() {
        totalPausedSeconds += Int(Date().timeIntervalSince(startDate))
        elapsedSeconds = totalPausedSeconds
        isPaused = true
        timer?.invalidate()
        timer = nil
        persistState()
    }

    func resumeTimer() {
        startDate = Date()
        isPaused = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds = self.totalPausedSeconds + Int(Date().timeIntervalSince(self.startDate))
            self.persistState()
            self.onTick?()
        }
        RunLoop.main.add(timer!, forMode: .common)
        persistState()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func persistState() {
        ActiveTrackingPersistence.save(
            activityId: activity.id,
            startDate: startDate,
            totalPausedSeconds: totalPausedSeconds,
            isPaused: isPaused
        )
    }

    func formattedTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h >= 1 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    /// Effective elapsed seconds for saving (used when stopping).
    func effectiveElapsedSeconds() -> Int {
        isPaused ? totalPausedSeconds : (totalPausedSeconds + Int(Date().timeIntervalSince(startDate)))
    }
}
