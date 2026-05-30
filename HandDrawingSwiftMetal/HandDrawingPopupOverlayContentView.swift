//
//  HandDrawingPopupOverlayContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/05/31.
//

import SwiftUI

struct HandDrawingPopupOverlayContentView: View {

    let bindings: [PopupAnchorBinding]

    var body: some View {
        ZStack {
            ForEach(bindings) { binding in
                if let viewModel = binding.viewModel {
                    PopupView(viewModel, placement: viewModel.placement) {
                        binding.content
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
