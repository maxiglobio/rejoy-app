import SwiftUI
import SwiftData
import UIKit

struct ActivityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ActivityType.sortOrder) private var activityTypes: [ActivityType]
    let onSelect: (ActivityType) -> Void

    /// Fixed three columns — avoids `GridItem.adaptive` layout bugs with variable-height cells on large phones.
    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    private var visibleActivities: [ActivityType] {
        activityTypes.filter { !AppSettings.hiddenActivityTypeIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: gridColumns, alignment: .center, spacing: 16) {
                        ForEach(visibleActivities) { activity in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onSelect(activity)
                                dismiss()
                            } label: {
                                VStack(spacing: 0) {
                                    ZStack {
                                        Image(systemName: activity.symbolName)
                                            .font(AppFont.rounded(size: 30))
                                            .foregroundStyle(AppColors.rejoyOrange)
                                    }
                                    .frame(height: 44)
                                    .frame(maxWidth: .infinity)

                                    Spacer(minLength: 8)

                                    Text(L.activityName(activity.name, language: appLanguage))
                                        .font(AppFont.caption)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .minimumScaleFactor(0.78)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 20, alignment: .center)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(AppColors.dotsBorder, lineWidth: 1)
                                )
                                .shadow(
                                    color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.06),
                                    radius: colorScheme == .dark ? 8 : 10,
                                    x: 0,
                                    y: colorScheme == .dark ? 3 : 4
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                intentionFooter
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(L.string("start_activity", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguage)) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            ActivityType.seedDefaultActivitiesIfNeeded(modelContext: modelContext)
        }
    }

    /// Pinned below the grid (not `safeAreaInset` on `ScrollView`) so at medium sheet height the hint never overlaps tiles.
    private var intentionFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.rowDivider.opacity(0.55))
                .frame(height: 1)

            Text(L.string("activity_picker_intention_hint", language: appLanguage))
                .font(AppFont.rounded(size: 13, weight: .regular))
                .foregroundStyle(AppColors.sectionHeader)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}
