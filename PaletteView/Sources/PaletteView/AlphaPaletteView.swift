//
//  PaletteView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import Combine
import SwiftUI

public struct AlphaPaletteView<Palette>: View
where Palette: AlphaPaletteDisplayProtocol & ObservableObject {

    private let paletteHeight: CGFloat

    private let paddingVertical: CGFloat

    private let colorSize: CGFloat

    private let spacing: CGFloat

    private let backgroundColor: Color

    private let onTapAlpha: ((Int, Bool) -> Void)?

    @ObservedObject private var palette: Palette

    @State private var checkeredImage: UIImage? = nil

    /// - Parameter onTapAlpha: Called after a tap. The `Bool` is `true` when the current selection was tapped again.
    public init(
        palette: Palette,
        paletteHeight: CGFloat? = nil,
        spacing: CGFloat = 2,
        paddingVertical: CGFloat = 2,
        backgroundColor: UIColor = .lightGray.withAlphaComponent(0.15),
        onTapAlpha: ((Int, Bool) -> Void)? = nil
    ) {
        let paletteHeight = paletteHeight ?? PaletteViewMetrics.paletteHeight
        self.palette = palette
        self.paletteHeight = paletteHeight
        self.paddingVertical = paddingVertical
        self.colorSize = paletteHeight - paddingVertical * 2
        self.spacing = spacing
        self.backgroundColor = Color(backgroundColor)
        self.onTapAlpha = onTapAlpha
    }

    private func alpha(_ alpha: Int) -> CGFloat {
        CGFloat(alpha) / 255.0
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                ForEach(Array(palette.items.enumerated()), id: \.element.id) { index, item in
                    ColorCircle(
                        color: UIColor.black.withAlphaComponent(alpha(item.alpha)),
                        checkeredImage: checkeredImage,
                        size: colorSize,
                        selected: palette.selectedIndex == index
                    ) {
                        let didReselect = palette.selectedIndex == index
                        palette.select(index)
                        onTapAlpha?(index, didReselect)
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
private final class PreviewAlphaPalette: AlphaPaletteDisplayProtocol, ObservableObject {
    @Published var items: [AlphaPaletteItem]
    @Published var selectedIndex: Int

    init(alphas: [Int], selectedIndex: Int) {
        self.items = alphas.map { AlphaPaletteItem(alpha: $0) }
        self.selectedIndex = selectedIndex
    }

    func select(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
    }
}

private struct AlphaPalettePreview: View {
    @StateObject private var palette = PreviewAlphaPalette(
        alphas: [255, 225, 200, 175, 150, 125, 100, 50],
        selectedIndex: 3
    )

    var body: some View {
        VStack {
            Spacer()
            AlphaPaletteView(palette: palette)
                .frame(width: 256)
            Spacer()
        }
    }
}

#Preview {
    AlphaPalettePreview()
}
#endif
