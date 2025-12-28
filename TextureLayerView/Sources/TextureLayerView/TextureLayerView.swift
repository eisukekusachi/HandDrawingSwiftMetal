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

@MainActor
private struct PreviewView: View {
    private var viewModel = TextureLayerViewModel()

    private let textureLayers = TextureLayers(
        renderer: nil
    )

    private let state: TextureLayersState = .init(
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
        TextureLayerView(
            viewModel: viewModel
        )
        .frame(width: 320, height: 300)
        .onAppear {
            Task {
                await textureLayers.initialize(
                    textureLayersState: state
                )

                viewModel.initialize(
                    textureLayers: textureLayers
                )
            }
        }
    }
}

#Preview {
    PreviewView()
}
