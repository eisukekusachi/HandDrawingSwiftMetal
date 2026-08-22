//
//  PaletteView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import Combine
import SwiftUI

public struct ColorPaletteView<Palette>: View
where Palette: ColorPaletteDisplayProtocol & ObservableObject {

    private let paletteHeight: CGFloat

    private let paddingVertical: CGFloat

    private let colorSize: CGFloat

    private let spacing: CGFloat

    private let backgroundColor: Color

    private let onTapColor: ((Int, Bool) -> Void)?

    @ObservedObject private var palette: Palette

    @State private var checkeredImage: UIImage? = nil

    public init(
        palette: Palette,
        paletteHeight: CGFloat? = nil,
        spacing: CGFloat = 2,
        paddingVertical: CGFloat = 2,
        backgroundColor: UIColor = .lightGray.withAlphaComponent(0.15),
        onTapColor: ((Int, Bool) -> Void)? = nil
    ) {
        let paletteHeight = paletteHeight ?? PaletteViewMetrics.paletteHeight
        self.palette = palette
        self.paletteHeight = paletteHeight
        self.paddingVertical = paddingVertical
        self.colorSize = paletteHeight - paddingVertical * 2
        self.spacing = spacing
        self.backgroundColor = Color(backgroundColor)
        self.onTapColor = onTapColor
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                ForEach(Array(palette.items.enumerated()), id: \.element.id) { index, item in
                    ColorCircle(
                        color: item.color,
                        checkeredImage: checkeredImage,
                        size: colorSize,
                        selected: palette.selectedIndex == index
                    ) {
                        let didReselect = palette.select(index)
                        onTapColor?(index, didReselect)
                    }
                }
            }
            .padding(.horizontal, spacing)
        }
        .frame(height: paletteHeight)
        .padding(.vertical, paddingVertical)
        .background(backgroundColor)
        .cornerRadius(paletteHeight)
        .onAppear() {
            if checkeredImage == nil {
                checkeredImage = UIImage.checkerboardImage(
                    size: .init(width: colorSize, height: colorSize),
                    checkSize: 4,
                    dark: .init(white: 0.8, alpha: 1.0)
                )
            }
        }
    }
}

#if DEBUG
private final class PreviewColorPalette: ColorPaletteDisplayProtocol, ObservableObject {
    @Published var items: [ColorPaletteItem]
    @Published var selectedIndex: Int

    init(colors: [UIColor], selectedIndex: Int) {
        self.items = colors.map { ColorPaletteItem(color: $0) }
        self.selectedIndex = selectedIndex
    }

    func select(_ index: Int) -> Bool {
        guard items.indices.contains(index) else { return false }
        let didReselect = selectedIndex == index
        selectedIndex = index
        return didReselect
    }
}

private struct ColorPalettePreview: View {
    @StateObject private var palette = PreviewColorPalette(
        colors: [
            .black.withAlphaComponent(0.8),
            .gray.withAlphaComponent(0.8),
            .red.withAlphaComponent(0.8),
            .blue.withAlphaComponent(0.8),
            .green.withAlphaComponent(0.8),
            .yellow.withAlphaComponent(0.8),
            .purple.withAlphaComponent(0.8)
        ],
        selectedIndex: 5
    )

    var body: some View {
        VStack {
            Spacer()
            ColorPaletteView(palette: palette)
                .frame(width: 256)
            Spacer()
        }
    }
}

#Preview {
    ColorPalettePreview()
}
#endif
