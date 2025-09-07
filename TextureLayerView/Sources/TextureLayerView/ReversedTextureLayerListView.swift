//
//  ReversedTextureLayerListView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import CanvasView
import SwiftUI

public struct ReversedTextureLayerListView: View {

    @ObservedObject var viewModel: TextureLayerViewModel

    public var body: some View {
        List {
            ForEach(
                // In drawing apps, textures stack from bottom to top,
                // so the layer order is reversed compared to the default.
                Array(viewModel.layers.reversed()),
                id: \.id
            ) { layer in
                TextureLayerRowView(
                    layer: layer,
                    isSelected: viewModel.isSelected(layer.id),
                    defaultBackgroundColor: viewModel.defaultBackgroundColor,
                    selectedBackgroundColor: viewModel.selectedBackgroundColor,
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
    private let viewModel = TextureLayerViewModel()

    private let canvasState = TextureLayers()
    private let repository = MockTextureRepository()

    private let previewConfig: ResolvedProjectConfiguration = .init(
        projectName: "",
        textureSize: .zero,
        layerIndex: 0,
        layers: [
            .init(
                fileName: UUID().uuidString,
                title: "Layer0",
                alpha: 255,
                isVisible: true
            ),
            .init(
                fileName: UUID().uuidString,
                title: "Layer1",
                alpha: 200,
                isVisible: true
            ),
            .init(
                fileName: UUID().uuidString,
                title: "Layer2",
                alpha: 150,
                isVisible: true
            ),
            .init(
                fileName: UUID().uuidString,
                title: "Layer3",
                alpha: 100,
                isVisible: true
            ),
            .init(
                fileName: UUID().uuidString,
                title: "Layer4",
                alpha: 50,
                isVisible: true
            )
        ]
    )

    var body: some View {
        ReversedTextureLayerListView(
            viewModel: viewModel
        )
        .frame(width: 256, height: 300)
        .onAppear {
            Task {
                await canvasState.initialize(
                    configuration: previewConfig,
                    textureRepository: repository
                )
                
                viewModel.initialize(
                    configuration: .init(
                        textureLayers: canvasState,
                        textureRepository: repository,
                        undoStack: nil
                    )
                )
            }
        }
    }
}

#Preview {
    PreviewView()
}
