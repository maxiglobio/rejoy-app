import SwiftUI
import UIKit

/// Two stacked shelves with four offering bowls each; tap to place daily offerings (empty → filled).
///
/// Layout matches Figma **Dots-Platform** slide (`7qWOA6RjyIUhr3NSBtYbwX`, node `40023738:10089`):
/// shelf art **1186** pt wide, bowl row **932** pt wide (four **233×394** slots, no horizontal overlap).
struct AltBowlsShelvesView: View {
    @Environment(\.appLanguage) private var appLanguage
    @ObservedObject private var offeringState = OfferingBowlsState.shared

    @State private var transientOfferingIndex: Int?
    @State private var labelDismissTask: Task<Void, Never>?

    let contentWidth: CGFloat

    /// Source `shelf-top.png` / `shelf-bottom.png` size (matches Figma shelf width 1186).
    private static let shelfSourceSize = CGSize(width: 1186, height: 241)

    // MARK: - Figma geometry (node 40023738:10089)

    private static let figmaShelfWidth: CGFloat = 1186
    private static let figmaBowlRowWidth: CGFloat = 932
    private static let figmaBowlSlotWidth: CGFloat = 233
    private static let figmaBowlSlotHeight: CGFloat = 394

    /// Asset-compensation scale: bowl PNGs contain transparent margins, so we render larger than slot width.
    private static let bowlVisualScale: CGFloat = 1.38
    /// Optional manual horizontal correction for shelf art visual center.
    private static let bowlCenterXOffset: CGFloat = 0
    /// Small positive spacing between bowl slots on each shelf.
    private static let bowlGap: CGFloat = 6

    /// Bowl baseline anchor measured from shelf bottom in shelf-height units.
    /// Single normalized ratio keeps the same visual docking across screen sizes.
    private static let bowlBaselineOffsetRatio: CGFloat = 0.28

    var body: some View {
        let layout = Self.layout(for: contentWidth)
        /// Rows are measured with bowl overflow included; pull the second row up by part of that overflow.
        let interRowPullUp = max(0, layout.rowH - layout.shelfH) * 0.84

        return VStack(spacing: 0) {
            VStack(spacing: -interRowPullUp) {
                shelfRow(shelfImage: "AltarShelfTop", bowlIndices: 0 ..< 4, layout: layout)
                    .zIndex(1)
                shelfRow(shelfImage: "AltarShelfBottom", bowlIndices: 4 ..< 8, layout: layout)
                    .zIndex(0)
            }

            if let i = transientOfferingIndex {
                Text(L.string("offering_word_\(i + 1)", language: appLanguage))
                    .font(AppFont.rounded(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.trailing.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: transientOfferingIndex)
        .frame(width: contentWidth)
        .frame(maxWidth: .infinity)
        .onAppear { offeringState.refreshIfNewCalendarDay() }
        .onDisappear {
            labelDismissTask?.cancel()
            labelDismissTask = nil
        }
    }

    private struct ShelfRowLayout {
        let rowH: CGFloat
        let shelfH: CGFloat
        let bowlClusterWidth: CGFloat
        let bowlRowRenderWidth: CGFloat
        let slotWidth: CGFloat
        let bowlWidth: CGFloat
        let bowlMaxH: CGFloat
        let bowlBaselineOffset: CGFloat
    }

    private static func layout(for w: CGFloat) -> ShelfRowLayout {
        let shelfH = w * Self.shelfSourceSize.height / Self.shelfSourceSize.width
        let bowlClusterWidth = w * (Self.figmaBowlRowWidth / Self.figmaShelfWidth)
        let slotWidth = bowlClusterWidth / 4
        let bowlRowRenderWidth = bowlClusterWidth + 3 * Self.bowlGap
        let bowlWidth = slotWidth * Self.bowlVisualScale
        let bowlMaxH = bowlWidth * (Self.figmaBowlSlotHeight / Self.figmaBowlSlotWidth)
        let bowlBaselineOffset = shelfH * Self.bowlBaselineOffsetRatio
        let rowH = max(shelfH, bowlMaxH + bowlBaselineOffset)
        return ShelfRowLayout(
            rowH: rowH,
            shelfH: shelfH,
            bowlClusterWidth: bowlClusterWidth,
            bowlRowRenderWidth: bowlRowRenderWidth,
            slotWidth: slotWidth,
            bowlWidth: bowlWidth,
            bowlMaxH: bowlMaxH,
            bowlBaselineOffset: bowlBaselineOffset
        )
    }

    private func showTransientWord(for index: Int) {
        transientOfferingIndex = index
        labelDismissTask?.cancel()
        labelDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            transientOfferingIndex = nil
        }
    }

    private func shelfRow(shelfImage: String, bowlIndices: Range<Int>, layout: ShelfRowLayout) -> some View {
        let w = contentWidth

        return ZStack(alignment: .bottom) {
            Image(shelfImage)
                .resizable()
                .scaledToFit()
                .frame(width: w)
                .frame(maxWidth: .infinity)

            HStack(alignment: .bottom, spacing: Self.bowlGap) {
                ForEach(Array(bowlIndices), id: \.self) { idx in
                    let col = idx - bowlIndices.lowerBound
                    bowlButton(
                        index: idx,
                        hitWidth: layout.slotWidth,
                        bowlWidth: layout.bowlWidth,
                        bowlMaxH: layout.bowlMaxH
                    )
                    .zIndex(Double(col))
                }
            }
            .frame(width: layout.bowlRowRenderWidth, alignment: .center)
            // Lock centering to the same width used by the shelf art in this row.
            .frame(width: w, alignment: .center)
            .offset(x: Self.bowlCenterXOffset)
            .offset(y: -layout.bowlBaselineOffset)
        }
        .frame(width: w, height: layout.rowH, alignment: .bottom)
        .frame(maxWidth: .infinity)
    }

    private func bowlButton(index: Int, hitWidth: CGFloat, bowlWidth: CGFloat, bowlMaxH: CGFloat) -> some View {
        let filledName = "AltarBowl\(index + 1)"
        let emptyName = "AltarBowl\(index + 1)Empty"
        let isFilled = offeringState.isFilled(index)

        return Button {
            showTransientWord(for: index)
            if offeringState.isFilled(index) {
                let g = UIImpactFeedbackGenerator(style: .light)
                g.impactOccurred(intensity: 0.45)
                return
            }
            let newFill = offeringState.tapBowl(at: index)
            if newFill {
                let g = UIImpactFeedbackGenerator(style: OfferingBowlsState.hapticStyle(forBowlIndex: index))
                g.impactOccurred(intensity: 1.0)
            }
        } label: {
            ZStack {
                Color.clear
                    .frame(width: hitWidth, height: bowlMaxH)
            }
            .frame(width: hitWidth, height: bowlMaxH)
            .overlay(alignment: .center) {
                Image(isFilled ? filledName : emptyName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: bowlWidth, height: bowlMaxH)
                    .allowsHitTesting(false)
            }
            // Keep taps unambiguous: each bowl owns only its slot-width hit area.
            .contentShape(Rectangle())
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isFilled)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.string("offering_a11y_\(index + 1)", language: appLanguage))
    }
}
