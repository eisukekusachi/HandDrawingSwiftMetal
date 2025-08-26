//
//  EraserPaletteView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import SwiftUI

struct EraserPaletteView: View {

    private let paletteHeight: CGFloat

    private let paddingVertical: CGFloat
    private let paddingHorizontal: CGFloat

    private let colorSize: CGFloat

    private let spacing: CGFloat

    private let backgroundColor: Color

    @ObservedObject private var palette: EraserPalette

    @State private var checkeredImage: UIImage? = nil

    public init(
        palette: EraserPalette,
        paletteHeight: CGFloat,
        spacing: CGFloat = 2,
        paddingVertical: CGFloat = 2,
        paddingHorizontal: CGFloat = 2,
        backgroundColor: UIColor = .lightGray.withAlphaComponent(0.15)
    ) {
        self.palette = palette
        self.paletteHeight = paletteHeight
        self.paddingVertical = paddingVertical
        self.paddingHorizontal = paddingHorizontal
        self.colorSize = paletteHeight - paddingVertical * 2
        self.spacing = spacing
        self.backgroundColor = Color(backgroundColor)
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
                        size: colorSize,
                        selected: palette.currentIndex == i
                    ) {
                        palette.select(i)
                    }
                }
            }
            .padding(.horizontal, spacing)
        }
        .frame(height: paletteHeight)
        .padding(.vertical, paddingVertical)
        .padding(.horizontal, paddingHorizontal)
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

private struct Preview: View {
    let paletteHeight: CGFloat = 32

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
                        255, 225, 200, 175, 150, 125, 100, 50, 25
                    ],
                    initialIndex: 3,
                    storage: EraserPaletteStorageStub()
                ),
                paletteHeight: paletteHeight
            )
            .frame(width: 256)
            Spacer()
        }
    }
}
#Preview {
    Preview()
}
