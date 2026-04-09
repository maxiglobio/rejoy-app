import SwiftUI
import UIKit

struct AdjustDurationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let activity: ActivityType
    @State var durationSeconds: Int
    let onConfirm: (Int) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text(L.activityName(activity.name, language: appLanguage))
                    .font(AppFont.title2)
                Image(systemName: activity.symbolName)
                    .font(AppFont.rounded(size: 40))
                    .foregroundStyle(AppColors.rejoyOrange)

                Text(formattedTime(durationSeconds))
                    .font(AppFont.rounded(size: 48, weight: .light))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(L.string("adjust_duration_hint", language: appLanguage))
                    .font(AppFont.rounded(size: 18, weight: .regular))
                    .foregroundStyle(.primary)

                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Spacer(minLength: 0)
                            durationControlsHStack
                            Spacer(minLength: 0)
                        }
                        .frame(minWidth: geo.size.width)
                    }
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding()
            .navigationTitle(L.string("adjust_duration", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguage)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("next", language: appLanguage)) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onConfirm(durationSeconds)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private let durationButtonBg = Color(red: 0.82, green: 0.82, blue: 0.82) // #d1d1d1

    private var durationControlsHStack: some View {
        HStack(spacing: 12) {
            durationButton("-30", size: 56, weight: .bold) { durationSeconds = max(0, durationSeconds - 1800) }
            durationButton("-5", size: 42, weight: .semibold) { durationSeconds = max(0, durationSeconds - 300) }
            durationButton("-1", size: 32, weight: .regular) { durationSeconds = max(0, durationSeconds - 60) }
            durationButton("+1", size: 32, weight: .regular) { durationSeconds += 60 }
            durationButton("+5", size: 42, weight: .semibold) { durationSeconds += 300 }
            durationButton("+30", size: 56, weight: .bold) { durationSeconds += 1800 }
        }
    }

    /// Matches `ProfileCalendarView` month sync: `easeInOut(duration: 0.25)`.
    private func animateDurationChange(_ update: () -> Void) {
        if accessibilityReduceMotion {
            update()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                update()
            }
        }
    }

    @ViewBuilder
    private func durationButton(_ label: String, size: CGFloat, weight: Font.Weight, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            animateDurationChange(action)
        } label: {
            Text(label)
                .font(AppFont.rounded(size: 20, weight: weight))
                .foregroundStyle(.black)
                .frame(width: size, height: size)
                .background(durationButtonBg)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    /// Whole minutes only (no seconds); underlying `durationSeconds` is unchanged.
    private func formattedTime(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let displayMinutes = total / 60
        if displayMinutes < 60 {
            return String(format: L.string("duration_adjust_total_minutes", language: appLanguage), displayMinutes)
        }
        let h = displayMinutes / 60
        let m = displayMinutes % 60
        return m > 0
            ? String(format: L.string("duration_h_min", language: appLanguage), h, m)
            : String(format: L.string("duration_h", language: appLanguage), h)
    }
}
