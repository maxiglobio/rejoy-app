import SwiftUI

struct SettingsSeedsView: View {
    @AppStorage("appLanguage") private var appLanguageStorage = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(L.string("seeds_per_second", language: appLanguageStorage))
                    Spacer()
                    Text("\(AppSettings.seedsPerSecond)")
                        .foregroundStyle(AppColors.dotsSecondaryText)
                }
                .listRowBackground(AppColors.listRowBackground)
            } header: {
                Text(L.string("seeds", language: appLanguageStorage))
            } footer: {
                Text(L.string("seeds_description", language: appLanguageStorage))
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L.string("seeds", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
    }
}
