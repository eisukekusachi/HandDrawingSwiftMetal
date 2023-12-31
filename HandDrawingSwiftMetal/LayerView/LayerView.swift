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
            LayerListView(layerManager: layerManager)
        }
        .padding(8)
        .background(Color.white.opacity(0.75))
        .border(.gray, width: 1)
    }
}

#Preview {
    LayerView(layerManager: LayerManager())
}
