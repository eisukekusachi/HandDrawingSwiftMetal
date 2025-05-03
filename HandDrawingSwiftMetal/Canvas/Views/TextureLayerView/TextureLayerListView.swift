//
//  TextureLayerListView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct TextureLayerListView: View {

    @ObservedObject var viewModel: TextureLayerViewModel

    var body: some View {
        List {
            ForEach(
                Array(viewModel.layers.reversed()),
                id: \.id
            ) { layer in
                layerRow(
                    layer: layer,
                    thumbnail: viewModel.getThumbnail(layer.id),
                    selected: viewModel.selectedLayer?.id == layer.id,
                    didTapRow: { targetLayer in
                        viewModel.selectLayer(targetLayer.id)
                    },
                    didTapVisibleButton: { targetLayer in
                        viewModel.updateLayer(
                            id: targetLayer.id,
                            isVisible: !targetLayer.isVisible
                        )
                    }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .onMove(perform: { source, destination in
                viewModel.moveLayer(
                    fromListOffsets: source,
                    toListOffset: destination
                )
            })
            .listRowSeparator(.hidden)
        }
        .listStyle(PlainListStyle())
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
                .init(title: "Layer0", alpha: 255),
                .init(title: "Layer1", alpha: 200),
                .init(title: "Layer2", alpha: 150),
                .init(title: "Layer3", alpha: 100),
                .init(title: "Layer4", alpha: 50),
            ]
        )
    )
    let viewModel: TextureLayerViewModel

    init() {
        viewModel = .init(canvasState: canvasState)
    }
    var body: some View {
        TextureLayerListView(
            viewModel: viewModel
        )
        .frame(width: 256, height: 300)
    }

}
