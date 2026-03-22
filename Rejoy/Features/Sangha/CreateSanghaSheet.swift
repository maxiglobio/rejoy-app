import SwiftUI

struct CreateSanghaSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    var onCreated: ((SanghaRow) -> Void)?

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
            .navigationTitle(L.string("create_sangha", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguage)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        createSangha()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
            .interactiveDismissDisabled(isCreating)
        }
    }

    private func createSangha() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let sangha = try await SanghaService.shared.createSangha(name: trimmed)
                await MainActor.run {
                    onCreated?(sangha)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
