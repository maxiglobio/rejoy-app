import SwiftUI

struct SettingsAccountView: View {
    @Binding var showLogOutAlert: Bool
    @AppStorage("appLanguage") private var appLanguageStorage = ""

    var body: some View {
        Form {
            Section(L.string("account", language: appLanguageStorage)) {
                Button(L.string("log_out", language: appLanguageStorage), role: .destructive) {
                    showLogOutAlert = true
                }
                .listRowBackground(AppColors.listRowBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L.string("account", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
    }
}
