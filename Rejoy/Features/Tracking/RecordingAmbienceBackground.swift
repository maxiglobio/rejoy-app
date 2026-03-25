import SwiftUI

private enum DedicationRecordingChrome {
    /// Refined vertical wash: #FF7A00 → #FF9A3D → #FFF4E8
    static let gradientTop = Color(red: 1, green: 122 / 255, blue: 0)
    static let gradientMid = Color(red: 1, green: 154 / 255, blue: 61 / 255)
    static let gradientBottom = Color(red: 1, green: 244 / 255, blue: 232 / 255)
}

/// Full-screen recording chrome: static orange wash (no animation).
struct RecordingAmbienceBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                DedicationRecordingChrome.gradientTop,
                DedicationRecordingChrome.gradientMid,
                DedicationRecordingChrome.gradientBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
