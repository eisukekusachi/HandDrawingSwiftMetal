//
//  TextureLayerView.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

public struct TextureLayerView: View {

    @ObservedObject private var viewModel: TextureLayerViewModel

    private let range: ClosedRange<Int> = 0 ... 255

    public init(
        viewModel: TextureLayerViewModel
    ) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack {
            TextureLayerToolbar(
                viewModel: viewModel
            )

            ReversedTextureLayerListView(
                viewModel: viewModel
            )

            TwoRowsSliderView(
                viewModel: viewModel,
                title: "Alpha",
                range: range
            )
            .padding(.top, 4)
            .padding([.leading, .trailing, .bottom], 8)
        }
    }

    public func update(_ state: TextureLayersState) {
        viewModel.update(state)
    }

    public func updateAlpha(_ alpha: Int) {
        viewModel.currentAlpha = alpha
    }
}

@MainActor
private struct PreviewView: View {
    var viewModel = TextureLayerViewModel(
        textureLayers: TextureLayersState(
            textureLayers: .init(
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
        ),
        device: nil,
        commandQueue: nil
    )
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
