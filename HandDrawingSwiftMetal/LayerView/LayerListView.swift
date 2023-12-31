//
//  LayerListView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct LayerListView: View {
    @ObservedObject var layerManager: LayerManager

    var body: some View {
        List {
            ForEach(Array(layerManager.layers.enumerated().reversed()),
                    id: \.element.id) { index, layer in

                layerRow(layer: layer,
                         selected: layerManager.isSelected(layer)) {

                    layerManager.index = index
                    layerManager.updateNonSelectedTextures()
                    layerManager.setNeedsDisplay = true
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
                    .onMove(perform: { source, destination in

                        layerManager.layers = layerManager.layers.reversed()
                        layerManager.moveLayer(fromOffsets: source, toOffset: destination)
                        layerManager.layers = layerManager.layers.reversed()

                        layerManager.updateSelectedIndex()
                        layerManager.updateNonSelectedTextures()
                        layerManager.setNeedsDisplay = true
                    })
                    .listRowSeparator(.hidden)
        }
        .listStyle(PlainListStyle())
    }
}

extension LayerListView {
    func layerRow(layer: LayerModel, selected: Bool, didTapRow: @escaping (() -> Void)) -> some View {
        return ZStack {
            Color(backgroundColor(selected))

            HStack {
                Spacer()
                    .frame(width: 8)

                if let image = layer.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .scaledToFit()
                        .background(Color.white)
                        .cornerRadius(4)
                }

                Text(layer.title)
                    .font(.subheadline)
                    .foregroundColor(Color(textColor(selected)))

                Spacer()
            }
            .onTapGesture {
                didTapRow()
            }
        }
    }
}

// Colors
extension LayerListView {
    private func backgroundColor(_ selected: Bool) -> UIColor {
        if selected {
            return UIColor(named: "reversalComponent") ?? .clear
        } else {
            return UIColor(named: "component") ?? .clear
        }
    }
    private func textColor(_ selected: Bool) -> UIColor {
        if selected {
            return UIColor(named: "component") ?? .clear
        } else {
            return UIColor(named: "reversalComponent") ?? .clear
        }
    }
}

#Preview {
    LayerListView(layerManager: LayerManager())
}
