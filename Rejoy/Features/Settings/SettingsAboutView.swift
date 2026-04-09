import SwiftUI

struct SettingsAboutView: View {
    @AppStorage("appLanguage") private var appLanguageStorage = ""

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section(L.string("about", language: appLanguageStorage)) {
                HStack {
                    Text(L.string("rej", language: appLanguageStorage))
                    Spacer()
                    Text(
                        String(
                            format: L.string("version_format", language: appLanguageStorage),
                            locale: AppLanguage(rawValue: appLanguageStorage)?.locale ?? Locale.current,
                            appVersion
                        )
                    )
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
