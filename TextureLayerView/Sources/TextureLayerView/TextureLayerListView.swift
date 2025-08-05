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

private struct TextureLayerRowView: View {
    @ObservedObject var layer: TextureLayerModel

    private let isSelected: Bool
    private let didTapRow: (TextureLayerModel) -> Void
    private let didTapVisibleButton: (TextureLayerModel) -> Void

    init(
        layer: TextureLayerModel,
        isSelected: Bool,
        didTapRow: @escaping (TextureLayerModel) -> Void,
        didTapVisibleButton: @escaping (TextureLayerModel) -> Void
    ) {
        self.layer = layer
        self.isSelected = isSelected
        self.didTapRow = didTapRow
        self.didTapVisibleButton = didTapVisibleButton
    }

    var body: some View {
        ZStack {
            Color(
                backgroundColor(isSelected)
            )

            HStack {
                Spacer()
                    .frame(width: 8)

                if let thumbnail = layer.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .scaledToFit()
                        .background(Color.white)
                        .cornerRadius(4)
                        .overlay(
                            Rectangle()
                                .stroke(.gray.opacity(0.5), lineWidth: 1.0)
                        )
                }

                Text(layer.title)
                    .font(.subheadline)
                    .foregroundColor(
                        Color(
                            textColor(isSelected)
                        )
                    )

                Spacer()

                Text("A: \(layer.alpha)")
                    .font(.caption2)
                    .foregroundColor(Color(uiColor: .gray))

                Image(systemName: layer.isVisible ? "eye" : "eye.slash.fill")
                    .frame(width: 32, height: 32)
                    .foregroundColor(
                        Color(
                            iconColor(layer: layer, isSelected)
                        )
                    )
                    .onTapGesture {
                        didTapVisibleButton(layer)
                    }

                Spacer()
                    .frame(width: 8)
            }
        }
        .onTapGesture {
            didTapRow(layer)
        }
    }

    private func backgroundColor(_ selected: Bool) -> UIColor {
        if selected {
            return UIColor(named: "component") ?? .clear
        } else {
            return UIColor(named: "reversalComponent") ?? .clear
        }
    }
    private func textColor(_ selected: Bool) -> UIColor {
        if selected {
            return UIColor(named: "reversalComponent") ?? .clear
        } else {
            return UIColor(named: "component") ?? .clear
        }
    }
    private func iconColor(layer: TextureLayerModel, _ selected: Bool) -> UIColor {
        if selected {
            return layer.isVisible ? .white : .lightGray
        } else {
            return layer.isVisible ? .black : .darkGray
        }
    }
}

#Preview {
    PreviewView()
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
