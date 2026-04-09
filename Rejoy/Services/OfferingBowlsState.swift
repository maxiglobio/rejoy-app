import Foundation
import CoreHaptics
import UIKit

/// Local daily offering state for the eight altar bowls (empty → filled on tap; resets each calendar day).
@MainActor
final class OfferingBowlsState: ObservableObject {
    static let shared = OfferingBowlsState()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let calendarDay = "offeringBowls.calendarDay"
        static let filledPattern = "offeringBowls.filledPattern"
    }

    /// Index 0…7 correspond to bowls 1…8 (top row 0–3, bottom row 4–7).
    @Published private(set) var filled: [Bool]
    private var hapticEngine: CHHapticEngine?

    private init() {
        if defaults.string(forKey: Keys.calendarDay) == nil {
            defaults.set(Self.todayKey(), forKey: Keys.calendarDay)
        }
        filled = Self.decode(defaults.string(forKey: Keys.filledPattern)) ?? Array(repeating: false, count: 8)
        ensureCurrentDay()
    }

    func isFilled(_ index: Int) -> Bool {
        guard index >= 0, index < 8 else { return false }
        return filled[index]
    }

    /// Returns true if this tap newly filled the bowl.
    @discardableResult
    func tapBowl(at index: Int) -> Bool {
        guard index >= 0, index < 8 else { return false }
        ensureCurrentDay()
        guard !filled[index] else { return false }

        let allFilledBefore = filled.allSatisfy { $0 }
        var next = filled
        next[index] = true
        filled = next
        save()

        if !allFilledBefore, filled.allSatisfy({ $0 }) {
            playCompletionHaptic()
        }
        return true
    }

    func refreshIfNewCalendarDay() {
        ensureCurrentDay()
    }

    private func ensureCurrentDay() {
        let today = Self.todayKey()
        let stored = defaults.string(forKey: Keys.calendarDay)
        guard stored != today else { return }
        defaults.set(today, forKey: Keys.calendarDay)
        filled = Array(repeating: false, count: 8)
        save()
    }

    private func save() {
        defaults.set(Self.encode(filled), forKey: Keys.filledPattern)
    }

    private static func todayKey() -> String {
        let cal = Calendar.current
        let d = cal.startOfDay(for: Date())
        let y = cal.component(.year, from: d)
        let m = cal.component(.month, from: d)
        let day = cal.component(.day, from: d)
        return String(format: "%04d-%02d-%02d", y, m, day)
    }

    private static func encode(_ bits: [Bool]) -> String {
        bits.map { $0 ? "1" : "0" }.joined()
    }

    private static func decode(_ s: String?) -> [Bool]? {
        guard let s, s.count == 8 else { return nil }
        return s.map { $0 == "1" }
    }

    static func hapticStyle(forBowlIndex index: Int) -> UIImpactFeedbackGenerator.FeedbackStyle {
        let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.soft, .light, .medium, .rigid, .soft, .light, .medium, .rigid]
        return styles[index % styles.count]
    }

    /// Longer completion haptic with rising intensity; falls back gracefully if advanced haptics are unavailable.
    private func playCompletionHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        do {
            if hapticEngine == nil {
                hapticEngine = try CHHapticEngine()
            }
            try hapticEngine?.start()

            let transients: [CHHapticEvent] = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ], relativeTime: 0.00),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.28)
                ], relativeTime: 0.08),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.48),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.36)
                ], relativeTime: 0.16),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.62),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
                ], relativeTime: 0.24)
            ]

            let swell = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                ],
                relativeTime: 0.30,
                duration: 0.55
            )

            let intensityCurve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0.30, value: 0.45),
                    .init(relativeTime: 0.57, value: 0.75),
                    .init(relativeTime: 0.85, value: 1.00)
                ],
                relativeTime: 0
            )

            let sharpnessCurve = CHHapticParameterCurve(
                parameterID: .hapticSharpnessControl,
                controlPoints: [
                    .init(relativeTime: 0.30, value: 0.30),
                    .init(relativeTime: 0.57, value: 0.45),
                    .init(relativeTime: 0.85, value: 0.60)
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: transients + [swell], parameterCurves: [intensityCurve, sharpnessCurve])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
