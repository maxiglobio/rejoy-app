import SwiftUI

struct JoinSanghaSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    var onJoined: ((SanghaRow) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.string("invite_code", language: appLanguage), text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } footer: {
                    Text(L.string("join_sangha_code_hint", language: appLanguage))
                }
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(AppFont.footnote)
                    }
                }
            }
            .navigationTitle(L.string("join_sangha", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguage)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        joinSangha()
                    }
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)
                }
            }
            .interactiveDismissDisabled(isJoining)
        }
    }

    private func joinSangha() {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isJoining = true
        errorMessage = nil
        Task {
            do {
                let sangha = try await SanghaService.shared.joinSangha(inviteCode: trimmed)
                await MainActor.run {
                    onJoined?(sangha)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isJoining = false
                }
            }
        }
    }
}
