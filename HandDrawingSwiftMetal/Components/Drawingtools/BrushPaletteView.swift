//
//  BrushPaletteView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import SwiftUI

struct BrushPaletteView: View {

    private let size: CGFloat

    private let spacing: CGFloat

    @ObservedObject private var palette: BrushPalette

    @Environment(\.displayScale) private var scale

    @State private var checkeredImage: UIImage? = nil

    public init(
        palette: BrushPalette,
        size: CGFloat,
        spacing: CGFloat = 2
    ) {
        self.palette = palette
        self.size = size
        self.spacing = spacing
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                ForEach(palette.colors.indices, id: \.self) { i in
                    ColorCircle(
                        color: palette.colors[i],
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

    class BrushPaletteStorageStub: BrushPaletteStorage {
        init(index: Int = 0, hexColors: [String] = []) {}
        func load() async throws -> (index: Int, hexColors: [String])? { nil }
        func save(index: Int, hexColors: [String]) async throws {}
    }

    var body: some View {
        VStack {
            Spacer()
            BrushPaletteView(
                palette: .init(
                    initialColors: [
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
                    initialIndex: 5,
                    storage: BrushPaletteStorageStub()
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
