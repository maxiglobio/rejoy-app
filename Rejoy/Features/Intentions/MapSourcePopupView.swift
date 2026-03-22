import SwiftUI
import SwiftData

struct MapSourcePopupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Intention.createdAt) private var intentions: [Intention]

    let sourceType: DataSourceType
    let sourceLabel: String
    var defaultIntentionId: UUID?
    let onComplete: () -> Void

    @State private var selectedIntentionId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    HStack {
                        Image(systemName: sourceType.icon)
                            .foregroundStyle(AppColors.dotsSecondaryText)
                        Text(sourceLabel)
                            .font(AppFont.headline)
                    }
                }

                Section("Map to Intention") {
                    Picker("Intention", selection: $selectedIntentionId) {
                        Text("Select…")
                            .tag(nil as UUID?)
                        ForEach(intentions) { intention in
                            Text("\(intention.emoji) \(intention.name)")
                                .tag(intention.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Map Source")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedIntentionId == nil, let defaultId = defaultIntentionId {
                    selectedIntentionId = defaultId
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Map") {
                        confirmMapping()
                    }
                    .disabled(selectedIntentionId == nil)
                }
            }
        }
    }

    private func confirmMapping() {
        guard let intentionId = selectedIntentionId else { return }
        let typeRaw = sourceType.rawValue
        let existing = (try? modelContext.fetch(FetchDescriptor<DedicationMapping>(
            predicate: #Predicate<DedicationMapping> { m in
                m.sourceTypeRaw == typeRaw && m.sourceLabel == sourceLabel
            }
        ))) ?? []
        for m in existing { modelContext.delete(m) }
        let mapping = DedicationMapping(sourceType: sourceType, sourceLabel: sourceLabel, intentionId: intentionId)
        modelContext.insert(mapping)
        try? modelContext.save()
        onComplete()
        dismiss()
    }
}
