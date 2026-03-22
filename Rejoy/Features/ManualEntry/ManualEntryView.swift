import SwiftUI
import SwiftData

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Intention.createdAt) private var intentions: [Intention]

    @State private var minutes: Double = 30
    @State private var label: String = ""
    @State private var selectedIntentionId: UUID?
    let onSave: (Double, String, UUID?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Entry") {
                    TextField("Label (e.g. Meditation)", text: $label)
                    Stepper("\(Int(minutes)) minutes", value: $minutes, in: 5...480, step: 5)
                }

                Section("Intention") {
                    Picker("Map to", selection: $selectedIntentionId) {
                        Text("None").tag(nil as UUID?)
                        ForEach(intentions) { intention in
                            Text("\(intention.emoji) \(intention.name)")
                                .tag(intention.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(label.isEmpty)
                }
            }
        }
    }

    private func save() {
        let eng = DedicationEngine()
        eng.setModelContext(modelContext)
        eng.addManualEntry(minutes: minutes, label: label.isEmpty ? "Manual" : label, intentionId: selectedIntentionId)
        onSave(minutes, label, selectedIntentionId)
        dismiss()
    }
}
