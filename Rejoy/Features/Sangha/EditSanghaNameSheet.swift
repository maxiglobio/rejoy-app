import SwiftUI

struct EditSanghaNameSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss

    let sangha: SanghaRow
    var onSaved: ((SanghaRow) -> Void)?

    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(sangha: SanghaRow, onSaved: ((SanghaRow) -> Void)? = nil) {
        self.sangha = sangha
        self.onSaved = onSaved
        _name = State(initialValue: sangha.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.string("sangha_name", language: appLanguage), text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(AppFont.footnote)
                    }
                }
            }
            .navigationTitle(L.string("edit_group_name", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguage)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("save", language: appLanguage)) {
                        save()
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != sangha.name
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != sangha.name else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let updated = try await SanghaService.shared.updateSanghaName(sanghaId: sangha.id, name: trimmed)
                await MainActor.run {
                    onSaved?(updated)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
