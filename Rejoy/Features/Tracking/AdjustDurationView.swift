import SwiftUI
import UIKit

struct AdjustDurationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
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

                Text(L.string("adjust_duration_hint", language: appLanguage))
                    .font(AppFont.rounded(size: 18, weight: .regular))
                    .foregroundStyle(.primary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 23) {
                        durationButton("-30", size: 56, weight: .bold) { durationSeconds = max(0, durationSeconds - 1800) }
                        durationButton("-5", size: 42, weight: .semibold) { durationSeconds = max(0, durationSeconds - 300) }
                        durationButton("-1", size: 32, weight: .regular) { durationSeconds = max(0, durationSeconds - 60) }
                        durationButton("+1", size: 32, weight: .regular) { durationSeconds += 60 }
                        durationButton("+5", size: 42, weight: .semibold) { durationSeconds += 300 }
                        durationButton("+30", size: 56, weight: .bold) { durationSeconds += 1800 }
                    }
                    .padding(.horizontal, 4)
                }

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

    @ViewBuilder
    private func durationButton(_ label: String, size: CGFloat, weight: Font.Weight, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
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

    private func formattedTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h >= 1 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
