import SwiftUI
import SwiftData
import UIKit

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    @Query(sort: \ActivityType.sortOrder) private var activityTypes: [ActivityType]
    let session: Session
    /// When set, user cannot Rejoy yet (meditation time). Shows explainer — same copy as former accumulating sheet.
    var rejoyAvailabilityUnlockText: String? = nil

    @State private var dedicationText: String
    @State private var showDeleteAlert = false
    @State private var showRejoyActivationExplainer = false
    @State private var showRejoyMeditationCarousel = false
    @AppStorage("rejoyedSessionIds") private var rejoyedIdsRaw = ""

    init(session: Session, rejoyAvailabilityUnlockText: String? = nil) {
        self.session = session
        self.rejoyAvailabilityUnlockText = rejoyAvailabilityUnlockText
        _dedicationText = State(initialValue: session.dedicationText)
    }

    private var activity: ActivityType? {
        activityTypes.first { $0.id == session.activityTypeId }
    }

    private var isRejoyed: Bool {
        rejoyedIdsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }.contains(session.id)
    }

    private var badgesSectionTitle: String {
        let activityName = activity.map { L.activityName($0.name, language: appLanguage) } ?? L.string("activity", language: appLanguage)
        return String(format: L.string("session_detail_badges_for_activity", language: appLanguage), activityName)
    }

    var body: some View {
        List {
            // 1. Badges (first)
            Section {
                ActivityStickerSharePanel(session: session, activity: activity, isRejoyed: isRejoyed, listEmbedded: true)
            } header: {
                Text(badgesSectionTitle)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            .listRowSeparator(.hidden)

            if !isRejoyed, let timingText = rejoyAvailabilityUnlockText {
                Section {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showRejoyActivationExplainer = true
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.rejoyOrange, AppColors.rejoyOrangePressed],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .shadow(color: AppColors.rejoyOrange.opacity(0.4), radius: 5, x: 0, y: 2)
                                Image(systemName: "sparkles")
                                    .font(AppFont.rounded(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(L.string("session_detail_rejoy_activation_title", language: appLanguage))
                                    .font(AppFont.rounded(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(timingText)
                                    .font(AppFont.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(AppColors.rejoyOrange)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(AppColors.rejoyOrange.opacity(0.16))
                                    )
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(AppFont.caption.weight(.semibold))
                                .foregroundStyle(AppColors.rejoyOrange.opacity(0.55))
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(L.string("session_detail_rejoy_activation_a11y_hint", language: appLanguage))
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.dotsRejoyPillBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppColors.rejoyOrange.opacity(0.32), lineWidth: 1)
                        )
                        .shadow(color: AppColors.rejoyOrange.opacity(0.14), radius: 8, x: 0, y: 3)
                )
                .listRowSeparator(.hidden)
            }

            // 2. Dedication
            Section(L.string("dedication", language: appLanguage)) {
                TextEditor(text: $dedicationText)
                    .frame(minHeight: 80, maxHeight: 200)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

            // 3. Start / end time
            Section(L.string("time", language: appLanguage)) {
                Text(formatDate(session.startDate))
                Text(formatDate(session.endDate))
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        }
        .listSectionSpacing(10)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L.string("activity_details", language: appLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L.string("done", language: appLanguage)) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    session.dedicationText = dedicationText
                    try? modelContext.save()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showDeleteAlert = true
                    } label: {
                        Label(L.string("delete_activity", language: appLanguage), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.medium))
                }
                .accessibilityLabel(L.string("more_options", language: appLanguage))
            }
        }
        .sheet(isPresented: $showRejoyActivationExplainer) {
            RejoyActivationExplainerSheet {
                showRejoyActivationExplainer = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    showRejoyMeditationCarousel = true
                }
            }
        }
        .sheet(isPresented: $showRejoyMeditationCarousel) {
            RejoyMeditationCarouselSheet()
        }
        .alert(L.string("delete_activity_confirm", language: appLanguage), isPresented: $showDeleteAlert) {
            Button(L.string("cancel", language: appLanguage), role: .cancel) { }
            Button(L.string("delete", language: appLanguage), role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                let sessionId = session.id
                modelContext.delete(session)
                try? modelContext.save()
                Task {
                    try? await SupabaseService.shared.deleteSession(id: sessionId)
                }
                dismiss()
            }
        } message: {
            Text(L.string("cannot_undo", language: appLanguage))
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = AppLanguage(rawValue: appLanguage)?.locale ?? Locale.current
        return formatter.string(from: date)
    }
}

// MARK: - Rejoy activation explainer (full copy from compact row)

private struct RejoyActivationExplainerSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    let onLearnMore: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L.string("session_detail_rejoy_activation_body", language: appLanguage))
                        .font(AppFont.body)
                        .foregroundStyle(AppColors.dotsSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onLearnMore()
                    } label: {
                        Text(L.string("learn_more_rejoy_meditation", language: appLanguage))
                            .font(AppFont.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.rejoyOrange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.rejoyOrange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle(L.string("session_detail_rejoy_activation_title", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        dismiss()
                    }
                }
            }
        }
    }
}
