import SwiftUI
import SwiftData

struct DailySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = DedicationEngine()
    @State private var summary: DailySummary?
    @State private var showingManualEntry = false
    @State private var showingRitual = false
    @State private var selectedBlockForRejoy: TimeBlock?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(formattedDate)
                        .font(AppFont.headline)
                    if let s = summary {
                        Text("Total: \(Int(s.totalMinutes)) min")
                            .font(AppFont.title2)
                    }
                }

                if let s = summary, !s.bySource.isEmpty {
                    Section("By Source") {
                        ForEach(s.bySource) { block in
                            HStack {
                                Image(systemName: block.sourceType.icon)
                                    .foregroundStyle(AppColors.dotsSecondaryText)
                                Text(block.sourceLabel)
                                    .strikethrough(block.isRejoyed)

                                if block.isRejoyed {
                                    Text("Rejoyed")
                                        .font(AppFont.caption)
                                        .foregroundStyle(AppColors.dotsSecondaryText)
                                }

                                Spacer()
                                Text("\(Int(block.minutes)) min")
                                    .foregroundStyle(AppColors.dotsSecondaryText)

                                if !block.isRejoyed {
                                    Button("Rejoy") {
                                        selectedBlockForRejoy = block
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .opacity(block.isRejoyed ? 0.7 : 1)
                        }
                    }
                }

                if let s = summary, !s.byIntention.isEmpty {
                    Section("By Intention") {
                        ForEach(Array(s.byIntention.keys.sorted()), id: \.self) { name in
                            HStack {
                                Text(name)
                                Spacer()
                                Text("\(Int(s.byIntention[name] ?? 0)) min")
                                    .foregroundStyle(AppColors.dotsSecondaryText)
                            }
                        }
                    }
                }

                Section {
                    WeeklyChartView(data: engine.weeklyData())
                }

                Section {
                    Button {
                        showingRitual = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Rejoice – Dedication Ritual")
                        }
                    }

                    Button {
                        showingManualEntry = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.tap")
                            Text("Add Manual Entry")
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                engine.setModelContext(modelContext)
                Task { await refresh() }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView(onSave: { _, _, _ in
                    Task { await refresh() }
                })
            }
            .sheet(isPresented: $showingRitual) {
                DedicationRitualView { message in
                    engine.saveRitualCompletion(message: message)
                }
            }
            .sheet(item: $selectedBlockForRejoy) { block in
                SourceRejoyPopupView(sourceLabel: block.sourceLabel) {
                    engine.markSourceRejoyed(sourceType: block.sourceType, sourceLabel: block.sourceLabel)
                    Task { await refresh() }
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }

    private func refresh() async {
        summary = await engine.refreshAll()
    }
}
