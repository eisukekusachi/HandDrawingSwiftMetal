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

    private let textureLayers = TextureLayers()
    private let repository = MockTextureRepository()

    private let configuration: ResolvedTextureLayerArrayConfiguration = .init(
        projectName: "",
        textureSize: .zero,
        layerIndex: 3,
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
        TextureLayerView(
            viewModel: viewModel
        )
        .frame(width: 320, height: 300)
        .onAppear {
            Task {
                await textureLayers.initialize(
                    configuration: configuration,
                    textureRepository: repository
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
