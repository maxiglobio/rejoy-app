import SwiftUI

struct SettingsAboutView: View {
    @AppStorage("appLanguage") private var appLanguageStorage = ""

    var body: some View {
        Form {
            Section(L.string("about", language: appLanguageStorage)) {
                HStack {
                    Text(L.string("rej", language: appLanguageStorage))
                    Spacer()
                    Text(L.string("version", language: appLanguageStorage))
                        .foregroundStyle(AppColors.dotsSecondaryText)
                }
                .listRowBackground(AppColors.listRowBackground)
                Text(L.string("about_description", language: appLanguageStorage))
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.dotsSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(AppColors.listRowBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L.string("about", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
    }
}
