import SwiftUI

struct ProfileVisibilityInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguageStorage = ""
    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    var onJoined: ((SanghaRow) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.rejoyOrange)
                    Text(L.string("profile_visibility_invite_title", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text(L.string("profile_visibility_invite_description", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 15, weight: .regular))
                        .foregroundStyle(AppColors.dotsSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField(L.string("insert_invite_code", language: appLanguageStorage), text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if let error = errorMessage {
                        Text(error)
                            .font(AppFont.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        joinSangha()
                    } label: {
                        Text(L.string("done", language: appLanguageStorage))
                            .font(AppFont.rounded(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isJoining ? Color.gray : AppColors.rejoyOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                    }
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)
                    .buttonStyle(.plain)
                }
                .padding(24)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguageStorage)) {
                        dismiss()
                    }
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
