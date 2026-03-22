import SwiftUI
import SwiftData

struct SettingsActivityTypesView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguageStorage = ""
    @AppStorage("hiddenActivityTypeIds") private var hiddenActivityTypeIdsRaw = ""
    @Query(sort: \ActivityType.sortOrder) private var activityTypes: [ActivityType]
    @Binding var activityToDelete: ActivityType?
    @Binding var activityToEdit: ActivityType?
    @Binding var showAddActivity: Bool

    private static let builtInNames = ["Meditation", "Yoga", "Walking", "Running", "Work", "Cooking", "Reading", "Family", "Study"]

    private var hiddenActivityIds: Set<UUID> {
        Set(hiddenActivityTypeIdsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    private var visibleActivities: [ActivityType] {
        activityTypes.filter { !hiddenActivityIds.contains($0.id) }
    }

    private var hiddenActivities: [ActivityType] {
        activityTypes.filter { hiddenActivityIds.contains($0.id) }
    }

    var body: some View {
        Form {
            Section(L.string("activity_types", language: appLanguageStorage)) {
                ForEach(visibleActivities) { activity in
                    HStack {
                        Image(systemName: activity.symbolName)
                            .foregroundStyle(AppColors.rejoyOrange)
                            .frame(width: 28)
                        Text(L.activityName(activity.name, language: appLanguageStorage))
                        if activity.isBuiltIn || Self.builtInNames.contains(activity.name) {
                            Text(L.string("default", language: appLanguageStorage))
                                .font(AppFont.caption2)
                                .foregroundStyle(AppColors.dotsSecondaryText)
                        }
                        Spacer()
                        if !activity.isBuiltIn && !Self.builtInNames.contains(activity.name) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                activityToEdit = activity
                            } label: {
                                Image(systemName: "pencil")
                                    .font(AppFont.body)
                                    .foregroundStyle(AppColors.dotsSecondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            activityToDelete = activity
                        } label: {
                            Image(systemName: "trash")
                                .font(AppFont.body)
                                .foregroundStyle(AppColors.dotsSecondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(AppColors.listRowBackground)
                }
                .onMove(perform: moveActivities)
                Button(L.string("add_activity", language: appLanguageStorage)) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showAddActivity = true
                }
                .listRowBackground(AppColors.listRowBackground)
            }
            if !hiddenActivities.isEmpty {
                Section {
                    ForEach(hiddenActivities) { activity in
                        HStack {
                            Image(systemName: activity.symbolName)
                                .foregroundStyle(AppColors.dotsSecondaryText)
                                .frame(width: 28)
                            Text(L.activityName(activity.name, language: appLanguageStorage))
                            Spacer()
                            Button(L.string("restore_activity", language: appLanguageStorage)) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                var ids = hiddenActivityIds
                                ids.remove(activity.id)
                                hiddenActivityTypeIdsRaw = ids.map(\.uuidString).joined(separator: ",")
                            }
                            .foregroundStyle(AppColors.rejoyOrange)
                        }
                        .listRowBackground(AppColors.listRowBackground)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L.string("activity_types", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .onAppear {
            ActivityType.seedDefaultActivitiesIfNeeded(modelContext: modelContext)
        }
        .sheet(isPresented: $showAddActivity) {
            AddActivityView()
        }
        .sheet(item: $activityToEdit) { activity in
            EditActivityView(activity: activity)
        }
        .alert(L.string("delete_activity_confirm", language: appLanguageStorage), isPresented: Binding(
            get: { activityToDelete != nil },
            set: { if !$0 { activityToDelete = nil } }
        )) {
            Button(L.string("delete", language: appLanguageStorage), role: .destructive) {
                if let activity = activityToDelete {
                    performDelete(activity)
                }
                activityToDelete = nil
            }
            Button(L.string("cancel", language: appLanguageStorage), role: .cancel) {
                activityToDelete = nil
            }
        }
    }

    private func performDelete(_ activity: ActivityType) {
        let isBuiltIn = activity.isBuiltIn || Self.builtInNames.contains(activity.name)
        if isBuiltIn {
            var ids = hiddenActivityIds
            ids.insert(activity.id)
            hiddenActivityTypeIdsRaw = ids.map(\.uuidString).joined(separator: ",")
        } else {
            modelContext.delete(activity)
        }
        try? modelContext.save()
    }

    private func moveActivities(from source: IndexSet, to destination: Int) {
        var reordered = visibleActivities
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, activity) in reordered.enumerated() {
            activity.sortOrder = index
        }
        try? modelContext.save()
    }
}
