import SwiftUI
import SwiftData
import UIKit

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    @Query(sort: \ActivityType.sortOrder) private var activityTypes: [ActivityType]
    let session: Session

    @State private var dedicationText: String
    @State private var showDeleteAlert = false
    @State private var showShareSheet = false
    @AppStorage("rejoyedSessionIds") private var rejoyedIdsRaw = ""

    init(session: Session) {
        self.session = session
        _dedicationText = State(initialValue: session.dedicationText)
    }

    private var activity: ActivityType? {
        activityTypes.first { $0.id == session.activityTypeId }
    }

    private var isRejoyed: Bool {
        rejoyedIdsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }.contains(session.id)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: activity?.symbolName ?? "circle")
                        .font(AppFont.title)
                        .foregroundStyle(AppColors.rejoyOrange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.map { L.activityName($0.name, language: appLanguage) } ?? L.string("activity", language: appLanguage))
                            .font(AppFont.headline)
                        Text("\(L.formattedTimelineMinutes(session.durationSeconds, language: appLanguage)) · \(String(format: L.string("seeds_count", language: appLanguage), session.seeds))")
                            .font(AppFont.subheadline)
                            .foregroundStyle(AppColors.dotsSecondaryText)
                    }
                }
            }

            Section(L.string("time", language: appLanguage)) {
                Text(formatDate(session.startDate))
                Text(formatDate(session.endDate))
            }

            Section(L.string("dedication", language: appLanguage)) {
                TextEditor(text: $dedicationText)
                    .frame(minHeight: 80, maxHeight: 200)
            }

            Section {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showShareSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                        Text(L.string("share_activity", language: appLanguage))
                            .font(AppFont.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.rejoyOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Section {
                Button(L.string("delete_activity", language: appLanguage), role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showDeleteAlert = true
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L.string("session", language: appLanguage))
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
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareActivitySheet(
                session: session,
                activity: activity,
                isRejoyed: isRejoyed
            )
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
