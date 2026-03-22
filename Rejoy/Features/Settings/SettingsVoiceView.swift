import SwiftUI

struct SettingsVoiceView: View {
    @Binding var recognitionLocale: String
    @AppStorage("appLanguage") private var appLanguageStorage = ""

    var body: some View {
        Form {
            Section {
                Picker(L.string("recognition_language", language: appLanguageStorage), selection: $recognitionLocale) {
                    Text(L.string("automatic_russian", language: appLanguageStorage)).tag("")
                    Text(L.string("russian", language: appLanguageStorage)).tag("ru-RU")
                    Text(L.string("english", language: appLanguageStorage)).tag("en-US")
                    Text(L.string("ukrainian", language: appLanguageStorage)).tag("uk-UA")
                }
                .listRowBackground(AppColors.listRowBackground)
            } header: {
                Text(L.string("voice", language: appLanguageStorage))
            } footer: {
                Text(L.string("voice_footer", language: appLanguageStorage))
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L.string("voice", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            recognitionLocale = AppSettings.recognitionLocaleIdentifier
        }
        .onChange(of: recognitionLocale) { _, newValue in
            AppSettings.recognitionLocaleIdentifier = newValue
        }
    }
}
