import SwiftUI
import SwiftData

struct PendingSourceMapping: Identifiable {
    let id = UUID()
    let type: DataSourceType
    let label: String
}

struct SourceMappingView: View {
    @Environment(\.modelContext) private var modelContext

    let intention: Intention
    @State private var showEditSheet = false
    @State private var pendingMapping: PendingSourceMapping?
    @Query private var mappings: [DedicationMapping]
    @Query private var intentions: [Intention]

    private var availableSources: [(DataSourceType, String)] {
        [
            (.healthKitWorkout, "Workouts"),
            (.healthKitSteps, "Steps"),
            (.healthKitExercise, "Exercise Time"),
            (.healthKitMindful, "Mindful Sessions"),
            (.healthKitSleep, "Sleep"),
            (.motionPedometer, "Walking/Running"),
            (.locationPlace, "Time in Places"),
            (.calendarEvents, "Calendar Events"),
            (.manualEntry, "Manual Entry")
        ]
    }

    var body: some View {
        List {
            Section {
                Text("Map data sources to \(intention.emoji) \(intention.name)")
                    .font(AppFont.subheadline)
            }

            Section("Sources") {
                ForEach(availableSources, id: \.0.rawValue) { type, label in
                    let isMapped = mappings.contains { $0.sourceType == type && $0.sourceLabel == label && $0.intentionId == intention.id }
                    HStack {
                        Image(systemName: type.icon)
                        Text(label)
                        Spacer()
                        if isMapped {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.rejoyOrange)
                        } else {
                            Button("Map") {
                                pendingMapping = PendingSourceMapping(type: type, label: label)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Map Sources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            IntentionEditorView(intention: intention)
        }
        .sheet(item: $pendingMapping) { source in
            MapSourcePopupView(
                sourceType: source.type,
                sourceLabel: source.label,
                defaultIntentionId: intention.id
            ) {
                pendingMapping = nil
            }
        }
    }

}
