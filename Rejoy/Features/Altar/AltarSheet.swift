import SwiftUI

/// Optional full-screen sheet wrapper around `AltarEditorContent` (e.g. deep links or future entry points).
struct AltarSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AltarEditorContent()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(L.string("altar_title", language: appLanguage))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color(white: 0.97), for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.string("done", language: appLanguage)) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.large])
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}
