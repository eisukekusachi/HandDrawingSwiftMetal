//
//  LayerView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

struct LayerView: View {
    @ObservedObject var layerManager: LayerManager
    @ObservedObject var layerViewPresentation: LayerViewPresentation
    @ObservedObject var layerUndoManager: LayerUndoManager

    @State var isTextFieldPresented: Bool = false
    @State var textFieldTitle: String = ""

    let sliderStyle = SliderStyleImpl(
        trackLeftColor: UIColor(named: "trackColor")!)
    let range = 0 ... 255

    var body: some View {
        ZStack {
            layerViewPresentation.viewWithTopArrow(
                arrowSize: layerViewPresentation.arrowSize,
                roundedCorner: layerViewPresentation.roundedCorner
            )

            VStack {
                toolbar(layerManager: layerManager)
                listView(
                    layerManager: layerManager, 
                    layerUndoManager: layerUndoManager
                )
                selectedTextureAlphaSlider(layerManager: layerManager)
            }
            .padding(layerViewPresentation.edgeInsets)
        }
    }

}

extension LayerView {
    func toolbar(layerManager: LayerManager) -> some View {
        let buttonSize: CGFloat = 20

        return HStack {
            Button(action: {
                layerUndoManager.addUndoObjectToUndoStack()
                layerManager.addLayer()
                layerManager.refreshCanvasWithMergingAllLayers()

            }, label: {
                Image(systemName: "plus.circle")
                    .buttonModifier(diameter: buttonSize)
            })

            Spacer()
                .frame(width: 16)

            Button(action: {
                if layerManager.layers.count > 1 {
                    layerUndoManager.addUndoObjectToUndoStack()
                    layerManager.removeLayer()
                    layerManager.refreshCanvasWithMergingAllLayers()
                }

            }, label: {
                Image(systemName: "minus.circle")
                    .buttonModifier(diameter: buttonSize)
            })

            Spacer()
                .frame(width: 16)

            Button(action: {
                guard let selectedLayer = layerManager.selectedLayer else { return }
                textFieldTitle = selectedLayer.title
                isTextFieldPresented = true

            }, label: {
                Image(systemName: "pencil")
                    .buttonModifier(diameter: buttonSize)
            })
            .alert("Enter a title", isPresented: $isTextFieldPresented) {
                TextField("Enter a title", text: $textFieldTitle)
                Button("OK", action: {
                    guard let selectedLayer = layerManager.selectedLayer else { return }
                    layerManager.updateTitle(selectedLayer,
                                             $textFieldTitle.wrappedValue)
                })
                Button("Cancel", action: {})
            }

            Spacer()
        }
        .padding(8)
    }
    func listView(
        layerManager: LayerManager,
        layerUndoManager: LayerUndoManager
    ) -> some View {

        LayerListView(
            layerManager: layerManager,
            layerUndoManager: layerUndoManager
        )
    }
    func selectedTextureAlphaSlider(layerManager: LayerManager) -> some View {
        TwoRowsSliderView(
            title: "Alpha",
            value: layerManager.selectedLayerAlpha,
            style: sliderStyle,
            range: range) { value in
                guard let selectedLayer = layerManager.selectedLayer else { return }
                layerManager.updateAlpha(selectedLayer, value)
                layerManager.refreshCanvasWithMergingDrawingLayers()
        }
            .padding(.top, 4)
            .padding([.leading, .trailing, .bottom], 8)
    }
}

#Preview {
    LayerView(
        layerManager: LayerManager(),
        layerViewPresentation: LayerViewPresentation(),
        layerUndoManager: LayerUndoManager()
    )
}
