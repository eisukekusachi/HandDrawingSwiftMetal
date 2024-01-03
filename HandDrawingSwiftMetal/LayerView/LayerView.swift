//
//  LayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct LayerView: View {
    @ObservedObject var layerManager: LayerManager
    let sliderStyle = SliderStyleImpl(
        trackLeftColor: UIColor(named: "trackColor")!)
    let range = 0 ... 255

    var body: some View {
        VStack {
            toolbar(layerManager: layerManager)
            listView(layerManager: layerManager)
            selectedTextureAlphaSlider(layerManager: layerManager)
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

            }, label: {
                Image(systemName: "plus")
                    .buttonModifier(diameter: buttonSize)
            })

            Spacer()
                .frame(width: 16)

            Button(action: {
                layerManager.removeLayer()

            }, label: {
                Image(systemName: "minus")
                    .buttonModifier(diameter: buttonSize)
            })

            Spacer()
        }
        .padding(8)
    }
    func listView(layerManager: LayerManager) -> some View {
        LayerListView(layerManager: layerManager)
    }
    func selectedTextureAlphaSlider(layerManager: LayerManager) -> some View {
        TwoRowsSliderView(
            title: "Alpha",
            value: $layerManager.selectedLayerAlpha,
            style: sliderStyle,
            range: range) { value in
                if let layer = layerManager.selectedLayer {
                    layerManager.updateLayerAlpha(layer, value)
                }
        }
            .padding(.top, 4)
            .padding([.leading, .trailing, .bottom], 8)
    }

}

#Preview {
    LayerView(layerManager: LayerManager())
}
