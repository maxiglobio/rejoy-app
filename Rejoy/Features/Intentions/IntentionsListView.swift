import SwiftUI
import SwiftData

struct IntentionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Intention.createdAt) private var intentions: [Intention]

    @State private var showingNewIntention = false
    @State private var selectedIntention: Intention?

    var body: some View {
        NavigationStack {
            List {
                ForEach(intentions) { intention in
                    NavigationLink(value: intention) {
                        HStack {
                            Text(intention.emoji)
                                .font(AppFont.title2)
                            Text(intention.name)
                                .font(AppFont.headline)
                        }
                    }
                }
            }
            .navigationTitle("Intentions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewIntention = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingNewIntention) {
                IntentionEditorView(intention: nil)
            }
            .navigationDestination(for: Intention.self) { intention in
                SourceMappingView(intention: intention)
            }
        }
    }
}
