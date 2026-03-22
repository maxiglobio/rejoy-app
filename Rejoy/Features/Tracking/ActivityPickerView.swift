import SwiftUI
import SwiftData

struct ActivityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    @Query(sort: \ActivityType.sortOrder) private var activityTypes: [ActivityType]
    let onSelect: (ActivityType) -> Void

    private var visibleActivities: [ActivityType] {
        activityTypes.filter { !AppSettings.hiddenActivityTypeIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 16),
                ], spacing: 16) {
                    ForEach(visibleActivities) { activity in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSelect(activity)
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: activity.symbolName)
                                    .font(AppFont.rounded(size: 32))
                                    .foregroundStyle(AppColors.rejoyOrange)
                                Text(L.activityName(activity.name, language: appLanguage))
                                    .font(AppFont.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.rejoyOrange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle(L.string("start_activity", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguage)) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            ActivityType.seedDefaultActivitiesIfNeeded(modelContext: modelContext)
        }
    }
}
