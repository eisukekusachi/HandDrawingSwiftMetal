//
//  HandDrawingPopupOverlayContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/05/31.
//

import PopupView
import SwiftUI

struct HandDrawingPopupOverlayContentView: View {

    let bindings: [PopupAnchorBinding]

    var body: some View {
        ZStack {
            ForEach(bindings) { binding in
                PopupView(
                    binding.viewModel,
                    placement: binding.placement,
                    content: { binding.content },
                    onClose: binding.onClose
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
