import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DailySummaryView()
                .tabItem {
                    Label("Summary", systemImage: "chart.bar")
                }
            IntentionsListView()
                .tabItem {
                    Label("Intentions", systemImage: "heart")
                }
            OnboardingView(onContinue: nil)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
