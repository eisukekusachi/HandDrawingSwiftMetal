//
//  LayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct LayerView: View {
    @ObservedObject var layerManager: LayerManager

    var body: some View {
        VStack {
            toolbar(layerManager: layerManager)
            LayerListView(layerManager: layerManager)
        }
        .padding(8)
        .background(Color.white.opacity(0.75))
        .border(.gray, width: 1)
    }
}

extension LayerView {
    func toolbar(layerManager: LayerManager) -> some View {
        let buttonSize: CGFloat = 15

        return HStack {
            Button(action: {
                layerManager.addLayer(layerManager.textureSize)
                layerManager.updateNonSelectedTextures()

            }, label: {
                Image(systemName: "plus")
                    .buttonModifier(diameter: buttonSize)
            })

            Spacer()
                .frame(width: 16)

            Button(action: {
                layerManager.removeLayer()
                layerManager.updateNonSelectedTextures()
                layerManager.setNeedsDisplay = true

            }, label: {
                Image(systemName: "minus")
                    .buttonModifier(diameter: buttonSize)
            })

            Spacer()
        }
        .padding(8)
    }
}

#Preview {
    LayerView(layerManager: LayerManager())
}
