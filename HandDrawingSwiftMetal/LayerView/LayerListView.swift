//
//  LayerListView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct LayerListView: View {
    @ObservedObject var layerManager: LayerManager
    @ObservedObject var layerUndoManager: LayerUndoManager

    var body: some View {
        List {
            ForEach(Array(layerManager.layers.reversed()),
                    id: \.id) { layer in

                layerRow(layer: layer,
                         selected: layerManager.selectedLayer == layer,
                         didTapRow: { selectedLayer in
                    layerManager.updateLayer(selectedLayer)
                    layerManager.refreshCanvasWithMergingAllLayers()
                },
                         didTapVisibleButton: { layer in
                    layerManager.updateVisibility(layer, !layer.isVisible)
                    layerManager.refreshCanvasWithMergingAllLayers()
                })
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
                    .onMove(perform: { source, destination in
                        if let selectedLayer = layerManager.selectedLayer {

                            layerUndoManager.addUndoObjectToUndoStack()

                            layerManager.moveLayer(
                                fromOffsets: source,
                                toOffset: destination,
                                selectedLayer: selectedLayer
                            )
                            layerManager.refreshCanvasWithMergingAllLayers()
                        }
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
extension LayerListView {
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
    LayerListView(
        layerManager: LayerManager(),
        layerUndoManager: LayerUndoManager()
    )
}
