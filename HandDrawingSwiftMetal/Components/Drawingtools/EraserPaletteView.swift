//
//  EraserPaletteView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import SwiftUI

struct EraserPaletteView: View {

    private let size: CGFloat

    private let spacing: CGFloat

    @ObservedObject private var palette: EraserPalette

    @Environment(\.displayScale) private var scale

    @State private var checkeredImage: UIImage? = nil

    public init(
        palette: EraserPalette,
        size: CGFloat,
        spacing: CGFloat = 2
    ) {
        self.palette = palette
        self.size = size
        self.spacing = spacing
    }

    private func alpha(_ alpha: Int) -> CGFloat {
        CGFloat(alpha) / 255.0
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                ForEach(palette.alphas.indices, id: \.self) { i in
                    ColorCircle(
                        color: UIColor.black.withAlphaComponent(alpha(palette.alphas[i])),
                        checkeredImage: checkeredImage,
                        size: size,
                        selected: palette.currentIndex == i
                    ) {
                        palette.select(i)
                    }
                }
            }
            .padding(.horizontal, spacing)
        }
        .frame(height: size)
        .background(.clear)
        .onAppear() {
            if checkeredImage == nil {
                checkeredImage = UIImage.checkerboardImage(
                    size: .init(width: size, height: size),
                    checkSize: 4,
                    dark: .init(white: 0.8, alpha: 1.0)
                )
            }
        }
    }
}

private struct Preview: View {
    let paletteSize: CGFloat = 32

    class EraserPaletteStorageStub: EraserPaletteStorage {
        init(index: Int = 0, alphas: [Int] = []) {}
        func load() async throws -> (index: Int, alphas: [Int])? { nil }
        func save(index: Int, alphas: [Int]) async throws {}
    }

    var body: some View {
        VStack {
            Spacer()
            EraserPaletteView(
                palette: .init(
                    initialAlphas: [
                        255, 225, 200, 150, 100, 50, 25
                    ],
                    initialIndex: 3,
                    storage: EraserPaletteStorageStub()
                ),
                size: paletteSize
            )
            .frame(width: 256)
            Spacer()
        }
    }
}
#Preview {
    Preview()
}
