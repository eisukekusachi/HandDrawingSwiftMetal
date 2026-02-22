//
//  BrushPaletteView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import SwiftUI

struct BrushPaletteView: View {

    private let paletteHeight: CGFloat

    private let paddingVertical: CGFloat

    private let colorSize: CGFloat

    private let spacing: CGFloat

    private let backgroundColor: Color

    @ObservedObject private var palette: BrushPalette

    @State private var checkeredImage: UIImage? = nil

    init(
        palette: BrushPalette,
        paletteHeight: CGFloat,
        spacing: CGFloat = 2,
        paddingVertical: CGFloat = 2,
        backgroundColor: UIColor = .lightGray.withAlphaComponent(0.15)
    ) {
        self.palette = palette
        self.paletteHeight = paletteHeight
        self.paddingVertical = paddingVertical
        self.colorSize = paletteHeight - paddingVertical * 2
        self.spacing = spacing
        self.backgroundColor = Color(backgroundColor)
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                ForEach(palette.colors.indices, id: \.self) { i in
                    ColorCircle(
                        color: palette.colors[i],
                        checkeredImage: checkeredImage,
                        size: colorSize,
                        selected: palette.index == i
                    ) {
                        palette.select(i)
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

private struct Preview: View {
    let paletteHeight: CGFloat = 32

    var body: some View {
        VStack {
            Spacer()
            BrushPaletteView(
                palette: .init(
                    colors: [
                        .red,
                        .blue,
                        .green,
                        UIColor.red.withAlphaComponent(0.5),
                        UIColor.blue.withAlphaComponent(0.5),
                        UIColor.green.withAlphaComponent(0.5),
                        UIColor.red.withAlphaComponent(0.25),
                        UIColor.blue.withAlphaComponent(0.25),
                        UIColor.green.withAlphaComponent(0.25)
                    ],
                    index: 5
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
