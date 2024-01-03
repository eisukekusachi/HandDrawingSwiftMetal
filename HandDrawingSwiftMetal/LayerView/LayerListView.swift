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
            ForEach(Array(layerManager.layers.reversed()),
                    id: \.id) { layer in

                layerRow(layer: layer,
                         selected: layerManager.isSelected(layer),
                         didTapRow: { layer in
                    if let index = layerManager.layers.firstIndex(of: layer) {
                        layerManager.setSelectedIndex(index)
                        if let alpha = layerManager.selectedLayer?.alpha {
                            layerManager.selectedTextureAlpha = alpha
                        }
                        layerManager.updateNonSelectedTextures()
                        layerManager.setNeedsDisplay = true
                    }
                },
                         didTapVisibleButton: { layer in
                    layerManager.setVisibility(layer, !layer.isVisible)
                    layerManager.updateNonSelectedTextures()
                    layerManager.setNeedsDisplay = true
                })
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
                    .onMove(perform: { source, destination in
                        layerManager.addUndoObject = true

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
    func layerRow(layer: LayerModel, 
                  selected: Bool,
                  didTapRow: @escaping ((LayerModel) -> Void),
                  didTapVisibleButton: @escaping ((LayerModel) -> Void)) -> some View {
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
            .onTapGesture {
                didTapRow(layer)
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
    private func iconColor(layer: LayerModel, _ selected: Bool) -> UIColor {
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
    LayerListView(layerManager: LayerManager())
}
