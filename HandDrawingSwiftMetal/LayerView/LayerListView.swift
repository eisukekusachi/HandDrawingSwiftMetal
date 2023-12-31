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
            ForEach(Array(layerManager.layers.enumerated()),
                    id: \.element.id) { _, layer in
                layerRow(layer: layer)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(PlainListStyle())
    }
}

extension LayerListView {
    func layerRow(layer: LayerModel) -> some View {
        ZStack {
            Color(backgroundColor)
                .cornerRadius(8)

            HStack {
                Spacer()
                    .frame(width: 8)

                if let image = layer.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .scaledToFit()
                        .background(Color.white)
                }

                Text(layer.title)
                    .font(.subheadline)
                    .foregroundColor(Color(textColor))

                Spacer()
            }
        }
    }
}

// Colors
extension LayerListView {
    private var backgroundColor: UIColor {
        return UIColor(named: "reversalComponent") ?? .clear
    }
    private var textColor: UIColor {
        return UIColor(named: "component") ?? .clear
    }
}

#Preview {
    LayerListView(layerManager: LayerManager())
}
