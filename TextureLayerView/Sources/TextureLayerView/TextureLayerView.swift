//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import CanvasView
import SwiftUI

public struct TextureLayerView: View {

    private let range: ClosedRange<Int> = 0 ... 255

    @ObservedObject private var viewModel: TextureLayerViewModel

    public init(
        viewModel: TextureLayerViewModel
    ) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack {
            TextureLayerToolbar(viewModel: viewModel)

            ReversedTextureLayerListView(viewModel: viewModel)

            TwoRowsSliderView(
                value: $viewModel.currentAlpha,
                isDragging: $viewModel.isDragging,
                title: "Alpha",
                range: range
            )
            .padding(.top, 4)
            .padding([.leading, .trailing, .bottom], 8)
        }
    }
}

private struct PreviewView: View {
    let viewModel = TextureLayerViewModel()

    init() {
        let canvasState = CanvasState()

        let layers: [TextureLayerItem] = [
            .init(
                textureName: UUID().uuidString,
                title: "Layer0",
                alpha: 255
            ),
            .init(
                textureName: UUID().uuidString,
                title: "Layer1",
                alpha: 200
            ),
            .init(
                textureName: UUID().uuidString,
                title: "Layer2",
                alpha: 150
            ),
            .init(
                textureName: UUID().uuidString,
                title: "Layer3",
                alpha: 100
            ),
            .init(
                textureName: UUID().uuidString,
                title: "Layer4",
                alpha: 50
            )
        ]

        let canvasResolvedConfiguration: CanvasResolvedConfiguration = .init(
            projectName: "",
            textureSize: .zero,
            layerIndex: 0,
            layers: layers.map { .init(item: $0, thumbnail: nil) }
        )

        canvasState.initialize(
            configuration: canvasResolvedConfiguration
        )

        viewModel.initialize(
            configuration: .init(
                canvasState: canvasState,
                textureRepository: MockTextureRepository(),
                undoStack: nil
            )
        )
    }
    var body: some View {
        TextureLayerView(
            viewModel: viewModel
        )
        .frame(width: 320, height: 300)
    }
}

#Preview {
    PreviewView()
}
