import Foundation

enum AppSettings {
    static let defaultSeedsPerSecond = 65

    private static let seedsPerSecondKey = "seedsPerSecond"
    private static let recognitionLocaleKey = "recognitionLocale"
    private static let rejoyMeditationTimeKey = "rejoyMeditationTime"
    private static let hiddenActivityTypeIdsKey = "hiddenActivityTypeIds"

    /// Activity type IDs the user has chosen to hide (remove from picker). Built-in activities stay in DB for session history.
    static var hiddenActivityTypeIds: Set<UUID> {
        get {
            guard let raw = UserDefaults.standard.string(forKey: hiddenActivityTypeIdsKey), !raw.isEmpty else {
                return []
            }
            return Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        }
        set {
            let raw = newValue.map(\.uuidString).joined(separator: ",")
            UserDefaults.standard.set(raw, forKey: hiddenActivityTypeIdsKey)
        }
    }

    /// Rejoy Meditation time (hour, minute). Nil = disabled.
    static var rejoyMeditationTime: DateComponents? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: rejoyMeditationTimeKey),
                  !raw.isEmpty else { return nil }
            let parts = raw.split(separator: ":")
            guard parts.count == 2,
                  let h = Int(parts[0]), let m = Int(parts[1]),
                  (0..<24).contains(h), (0..<60).contains(m) else { return nil }
            var dc = DateComponents()
            dc.hour = h
            dc.minute = m
            return dc
        }
        set {
            if let dc = newValue, let h = dc.hour, let m = dc.minute {
                UserDefaults.standard.set(String(format: "%02d:%02d", h, m), forKey: rejoyMeditationTimeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: rejoyMeditationTimeKey)
            }
        }
    }

    static var seedsPerSecond: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: seedsPerSecondKey)
            return value > 0 ? value : defaultSeedsPerSecond
        }
        set {
            UserDefaults.standard.set(newValue, forKey: seedsPerSecondKey)
        }
    }

    /// Preferred locale for speech recognition. Empty = automatic (try Russian, then device, then English).
    static var recognitionLocaleIdentifier: String {
        get { UserDefaults.standard.string(forKey: recognitionLocaleKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: recognitionLocaleKey) }
    }
}
