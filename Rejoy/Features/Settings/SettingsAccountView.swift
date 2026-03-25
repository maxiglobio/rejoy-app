import SwiftUI
import SwiftData
import UIKit

struct SettingsAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguageStorage = ""
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("hasCompletedStories") private var hasCompletedStories = false

    @State private var showLogOutAlert = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showDeleteError = false

    var body: some View {
        Form {
            Section {
                Button(L.string("log_out", language: appLanguageStorage), role: .destructive) {
                    showLogOutAlert = true
                }
                .listRowBackground(AppColors.listRowBackground)
            }

            Section {
                Button(L.string("delete_account", language: appLanguageStorage), role: .destructive) {
                    showDeleteConfirm = true
                }
                .disabled(isDeleting)
                .listRowBackground(AppColors.listRowBackground)
            } footer: {
                Text(L.string("delete_account_footer", language: appLanguageStorage))
                    .font(AppFont.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(L.string("account", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isDeleting {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
        .alert(L.string("log_out_confirm", language: appLanguageStorage), isPresented: $showLogOutAlert) {
            Button(L.string("log_out", language: appLanguageStorage), role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await performLogOut() }
            }
            Button(L.string("cancel", language: appLanguageStorage), role: .cancel) { }
        } message: {
            Text(L.string("log_out_confirm_message", language: appLanguageStorage))
        }
        .alert(L.string("delete_account_confirm", language: appLanguageStorage), isPresented: $showDeleteConfirm) {
            Button(L.string("delete_account", language: appLanguageStorage), role: .destructive) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                Task { await performDeleteAccount() }
            }
            Button(L.string("cancel", language: appLanguageStorage), role: .cancel) { }
        } message: {
            Text(L.string("delete_account_confirm_message", language: appLanguageStorage))
        }
        .alert(L.string("error", language: appLanguageStorage), isPresented: $showDeleteError) {
            Button(L.string("done", language: appLanguageStorage), role: .cancel) { }
        } message: {
            Text(L.string("delete_account_error", language: appLanguageStorage))
        }
    }

    @MainActor
    private func performLogOut() async {
        do {
            try await SupabaseService.shared.signOut()
        } catch {
            #if DEBUG
            print("[Rejoy] signOut failed: \(error)")
            #endif
        }
        hasSeenWelcome = false
        hasCompletedStories = false
    }

    @MainActor
    private func performDeleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            await SanghaService.shared.unsubscribeFromActiveTrackingChanges()
            try await SupabaseService.shared.deleteAccount()
            try LocalStore.wipeAfterAccountDeletion(modelContext: modelContext)
            hasSeenWelcome = false
            hasCompletedStories = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            #if DEBUG
            print("[Rejoy] deleteAccount failed: \(error)")
            #endif
            showDeleteError = true
        }
    }
}
