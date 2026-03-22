//
//  ReversedTextureLayerListView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

public struct ReversedTextureLayerListView: View {

    @ObservedObject var viewModel: TextureLayerViewModel

    public var body: some View {
        List {
            ForEach(
                // In drawing apps, textures stack from bottom to top,
                // so the layer order is reversed compared to the default.
                Array((viewModel.textureLayers.layers).reversed()),
                id: \.id
            ) { layer in
                TextureLayerItemView(
                    layer: layer,
                    isSelected: viewModel.isSelected(layer.id),
                    didTapRow: { targetLayer in
                        viewModel.onTapCell(
                            targetLayer.id
                        )
                    },
                    didTapVisibleButton: { targetLayer in
                        viewModel.onTapVisibleButton(
                            targetLayer.id,
                            isVisible: !targetLayer.isVisible
                        )
                    }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .onMove(perform: { source, destination in
                viewModel.onMoveLayer(
                    source: source,
                    destination: destination
                )
            })
            .listRowSeparator(.hidden)
        }
        .listStyle(PlainListStyle())
    }
}

private struct PreviewView: View {
    private let viewModel = TextureLayerViewModel()
    private let textureLayers = TextureLayersState()
    private let data: TextureLayersModel = .init(
        layers: [
            .init(
                id: LayerId(),
                title: "Layer0",
                alpha: 255,
                isVisible: true
            ),
            .init(
                id: LayerId(),
                title: "Layer1",
                alpha: 200,
                isVisible: true
            ),
            .init(
                id: LayerId(),
                title: "Layer2",
                alpha: 150,
                isVisible: true
            ),
            .init(
                id: LayerId(),
                title: "Layer3",
                alpha: 100,
                isVisible: true
            ),
            .init(
                id: LayerId(),
                title: "Layer4",
                alpha: 50,
                isVisible: true
            )
        ],
        layerIndex: 3,
        textureSize: .zero
    )

    var body: some View {
        ReversedTextureLayerListView(
            viewModel: viewModel
        )
        .frame(width: 256, height: 300)
        .onAppear {
            Task {
                textureLayers.update(data)
                viewModel.update(textureLayers)
            }
        }
    }
}

#Preview {
    PreviewView()
}
