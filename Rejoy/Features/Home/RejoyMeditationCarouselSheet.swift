import SwiftUI
import UIKit

struct RejoyMeditationCarouselSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let slides: [(symbol: String, titleKey: String, descKey: String)] = [
        ("sparkles", "rejoy_meditation_slide_1_title", "rejoy_meditation_slide_1_desc"),
        ("person.3.sequence.fill", "rejoy_meditation_slide_2_title", "rejoy_meditation_slide_2_desc"),
        ("hands.sparkles.fill", "rejoy_meditation_slide_3_title", "rejoy_meditation_slide_3_desc"),
        ("heart.fill", "rejoy_meditation_slide_4_title", "rejoy_meditation_slide_4_desc"),
        ("leaf.fill", "rejoy_meditation_slide_5_title", "rejoy_meditation_slide_5_desc"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        slideContent(for: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 320)
                .onChange(of: currentPage) { _, _ in
                    UISelectionFeedbackGenerator().selectionChanged()
                }

                paginationDots
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
            .navigationTitle(L.string("rejoy_meditation_carousel_title", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
            }
        }
    }

    private func slideContent(for index: Int) -> some View {
        let slide = slides[index]
        return VStack(spacing: 24) {
            Image(systemName: slide.symbol)
                .font(AppFont.rounded(size: 64))
                .foregroundStyle(AppColors.rejoyOrange)

            Text(L.string(slide.titleKey, language: appLanguage))
                .font(AppFont.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(L.string(slide.descKey, language: appLanguage))
                .font(AppFont.body)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }

    private var paginationDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.orange : Color.orange.opacity(0.3))
                    .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}
