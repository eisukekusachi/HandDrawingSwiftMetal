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

    var body: some View {
        if let canvasState = viewModel.canvasState {
            List {
                ForEach(
                    Array(canvasState.layers.reversed()),
                    id: \.id
                ) { layer in
                    layerRow(
                        layer: layer,
                        thumbnail: viewModel.thumbnail(layer.id),
                        selected: viewModel.selectedLayer?.id == layer.id,
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
}

extension TextureLayerListView {

    private func layerRow(
        layer: TextureLayerModel,
        thumbnail: UIImage?,
        selected: Bool,
        didTapRow: @escaping ((TextureLayerModel) -> Void),
        didTapVisibleButton: @escaping ((TextureLayerModel) -> Void)
    ) -> some View {
        ZStack {
            Color(backgroundColor(selected))

            HStack {
                Spacer()
                    .frame(width: 8)

                if let thumbnail {
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
                    .foregroundColor(Color(textColor(selected)))

                Spacer()

                Text("A: \(layer.alpha)")
                    .font(.caption2)
                    .foregroundColor(Color(uiColor: .gray))

                Image(systemName: layer.isVisible ? "eye" : "eye.slash.fill")
                    .frame(width: 32, height: 32)
                    .foregroundColor(Color(iconColor(layer: layer, selected)))
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

}

// Colors
extension TextureLayerListView {

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
            if layer.isVisible {
                return .white
            } else {
                return .lightGray
            }
        } else {
            if layer.isVisible {
                return .black
            } else {
                return .darkGray
            }
        }
    }
}

#Preview {
    PreviewView()
}

private struct PreviewView: View {
    let canvasState = CanvasState(
        CanvasConfiguration(
            layers: [
                .init(textureName: UUID().uuidString, title: "Layer0", alpha: 255),
                .init(textureName: UUID().uuidString, title: "Layer1", alpha: 200),
                .init(textureName: UUID().uuidString, title: "Layer2", alpha: 150),
                .init(textureName: UUID().uuidString, title: "Layer3", alpha: 100),
                .init(textureName: UUID().uuidString, title: "Layer4", alpha: 50),
            ]
        )
    )
    let viewModel = TextureLayerViewModel()

    init() {
        viewModel.initialize(
            configuration: .init(
                canvasState: canvasState,
                textureLayerRepository: MockTextureLayerRepository(),
                undoStack: nil
            )
        )
    }
    var body: some View {
        TextureLayerListView(
            viewModel: viewModel
        )
        .frame(width: 256, height: 300)
    }

}
