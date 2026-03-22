import SwiftUI

struct ActivitySymbolPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    @Binding var selectedSymbol: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    private let iconSize: CGFloat = 44

    var body: some View {
        NavigationStack {
            List {
                ForEach(ActivitySymbolOptions.allIncluding(selectedSymbol), id: \.category) { category, symbols in
                    Section(category) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(symbols, id: \.self) { symbol in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedSymbol = symbol
                                    dismiss()
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.system(size: iconSize * 0.5, weight: .medium))
                                        .foregroundStyle(selectedSymbol == symbol ? .white : .primary)
                                        .frame(width: iconSize, height: iconSize)
                                        .background(selectedSymbol == symbol ? AppColors.rejoyOrange : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle(L.string("icon", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        dismiss()
                    }
                }
            }
        }
    }
}
