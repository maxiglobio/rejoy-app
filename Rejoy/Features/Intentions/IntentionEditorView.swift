import SwiftUI
import SwiftData

struct IntentionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let intention: Intention?
    private var isNew: Bool { intention == nil }

    @State private var name: String = ""
    @State private var emoji: String = "✨"
    @State private var note: String = ""

    init(intention: Intention? = nil) {
        self.intention = intention
        _name = State(initialValue: intention?.name ?? "")
        _emoji = State(initialValue: intention?.emoji ?? "✨")
        _note = State(initialValue: intention?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Health, Service, Creative Work", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("What you're dedicating time to.")
                }
                Section {
                    TextField("e.g. 🎯 ⚡️ 🧘 ✨", text: $emoji)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Icon")
                } footer: {
                    Text("A short emoji shown next to this intention in lists.")
                }
                Section {
                    TextField("Reminder or context", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Note (optional)")
                }
            }
            .navigationTitle(isNew ? "New Intention" : "Edit Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        if isNew {
            let new = Intention(name: name, emoji: emoji.isEmpty ? "✨" : emoji, note: note)
            modelContext.insert(new)
        } else if let intention {
            intention.name = name
            intention.emoji = emoji.isEmpty ? "✨" : emoji
            intention.note = note
        }
        try? modelContext.save()
        dismiss()
    }
}
