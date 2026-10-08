//
//  Created by Eisuke Kusachi
//

import SwiftUI

struct BrushVerticalDiameterSlider: View {

    @Binding var brushDiameter: Int

    var body: some View {
        VerticalDiameterSlider(value: $brushDiameter)
    }
}

#if DEBUG
private struct BrushVerticalDiameterSliderPreview: View {

    @State private var brushDiameter = 12

    var body: some View {
        BrushVerticalDiameterSlider(brushDiameter: $brushDiameter)
            .frame(width: 44, height: 380)
            .padding()
    }
}

#Preview {
    BrushVerticalDiameterSliderPreview()
}
#endif
