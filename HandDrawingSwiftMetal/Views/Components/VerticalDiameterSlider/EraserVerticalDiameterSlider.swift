//
//  Created by Eisuke Kusachi
//

import SwiftUI

struct EraserVerticalDiameterSlider: View {

    @Binding var eraserDiameter: Int

    var body: some View {
        VerticalDiameterSlider(value: $eraserDiameter)
    }
}

#if DEBUG
private struct EraserVerticalDiameterSliderPreview: View {

    @State private var eraserDiameter = 24

    var body: some View {
        EraserVerticalDiameterSlider(eraserDiameter: $eraserDiameter)
            .frame(width: 44, height: 380)
            .padding()
    }
}

#Preview {
    EraserVerticalDiameterSliderPreview()
}
#endif
