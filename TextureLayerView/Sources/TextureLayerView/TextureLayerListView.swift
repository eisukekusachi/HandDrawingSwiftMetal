//
//  TextureLayerListView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import CanvasView
import SwiftUI

struct TextureLayerListView: View {

    @ObservedObject var viewModel: TextureLayerViewModel

    @ObservedObject var canvasState: CanvasState

    var body: some View {
        List {
            ForEach(
                Array(canvasState.layers.reversed()),
                id: \.id
            ) { layer in
                TextureLayerRowView(
                    layer: layer,
                    isSelected: viewModel.selectedLayer?.id == layer.id,
                    didTapRow: { targetLayer in
                        viewModel.onTapCell(id: targetLayer.id)
                    },
                    didTapVisibleButton: { targetLayer in
                        viewModel.onTapVisibleButton(
                            id: targetLayer.id,
                            isVisible: !targetLayer.isVisible
                        )
                    }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .onMove(perform: { source, destination in
                viewModel.onMoveLayer(source: source, destination: destination)
            })
            .listRowSeparator(.hidden)
        }
        .listStyle(PlainListStyle())
    }
}

private struct PreviewView: View {
    let canvasState = CanvasState()

    let viewModel = TextureLayerViewModel()

    init() {
        canvasState.initialize(
            configuration: CanvasConfiguration(
                layers: [
                    .init(textureName: UUID().uuidString, title: "Layer0", alpha: 255),
                    .init(textureName: UUID().uuidString, title: "Layer1", alpha: 200),
                    .init(textureName: UUID().uuidString, title: "Layer2", alpha: 150),
                    .init(textureName: UUID().uuidString, title: "Layer3", alpha: 100),
                    .init(textureName: UUID().uuidString, title: "Layer4", alpha: 50)
                ]
            )
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
        TextureLayerListView(
            viewModel: viewModel,
            canvasState: viewModel.canvasState!
        )
        .frame(width: 256, height: 300)
    }
}

#Preview {
    PreviewView()
}
