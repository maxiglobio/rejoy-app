import SwiftUI

struct AppLanguageView: View {
    @AppStorage("appLanguage") private var appLanguageStorage = ""

    var body: some View {
        Form {
            Section {
                Picker(L.string("language", language: appLanguageStorage), selection: $appLanguageStorage) {
                    Text("System").tag("")
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                    Text("Українська").tag("uk")
                }
                .listRowBackground(AppColors.listRowBackground)
            } header: {
                Text(L.string("app_language", language: appLanguageStorage))
            } footer: {
                Text(L.string("language_description", language: appLanguageStorage))
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L.string("app_language", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
    }
}
