//
//  TextureLayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import Combine
import SwiftUI

public struct TextureLayerView: View {

    @ObservedObject private var viewModel: TextureLayerViewModel

    private let range: ClosedRange<Int> = 0 ... 255

    private let device: MTLDevice?

    private let onChanged: ((TextureLayerEvent) -> Void)

    public init(
        device: MTLDevice?,
        viewModel: TextureLayerViewModel,
        onChanged: @escaping ((TextureLayerEvent) -> Void)
    ) {
        self.device = device
        self._viewModel = .init(wrappedValue: viewModel)
        self.onChanged = onChanged
    }

    public var body: some View {
        VStack {
            TextureLayerToolbar(
                device: device,
                viewModel: viewModel,
                onChanged: onChanged
            )

            ReversedTextureLayerListView(
                viewModel: viewModel,
                onChanged: onChanged
            )

            TwoRowsSliderView(
                value: $viewModel.currentAlpha,
                isDragging: $viewModel.isAlphaSliderDragging,
                title: "Alpha",
                range: range
            )
            .padding(.top, 4)
            .padding([.leading, .trailing, .bottom], 8)
        }
    }

    public func update(_ state: TextureLayersState, device: MTLDevice) {
        viewModel.update(state, device: device)
    }
}

@MainActor
private struct PreviewView: View {
    private var viewModel = TextureLayerViewModel(
        dependencies: .init()
    )

    private let textureLayers = TextureLayersState(
        device: MTLCreateSystemDefaultDevice()!
    )

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
        TextureLayerView(
            device: nil,
            viewModel: viewModel,
            onChanged: { _ in
                print("onChanged")
            }
        )
        .frame(width: 320, height: 300)
        .onAppear {
            Task {
                textureLayers.update(data)

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
