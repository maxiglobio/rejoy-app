import SwiftUI

struct SanghaInviteView: View {
    let sangha: SanghaRow
    @Environment(\.appLanguage) private var appLanguage

    private var inviteMessage: String {
        String(format: L.string("invite_message", language: appLanguage), sangha.inviteCode)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(L.string("invite_members", language: appLanguage))
                .font(AppFont.headline)
            ShareLink(
                item: inviteMessage,
                subject: Text("\(L.string("sangha", language: appLanguage)): \(sangha.name)")
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(L.string("invite", language: appLanguage))
                }
                .font(AppFont.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.rejoyOrange)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}
