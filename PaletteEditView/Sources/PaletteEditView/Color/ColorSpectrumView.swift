//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct ColorSpectrumView: View {
    @Binding var rgbColor: UIColor

    var body: some View {
        PickerImageView(
            imageResource: .spectrum,
            rgbColor: $rgbColor
        )
    }
}

#if DEBUG
private struct ColorSpectrumPreview: View {
    @State private var rgbColor: UIColor = .red

    var body: some View {
        VStack(spacing: 44) {
            ColorSpectrumView(rgbColor: $rgbColor)
                .frame(height: 360)

            Circle()
                .fill(Color(uiColor: rgbColor))
                .frame(width: 44, height: 44)
        }
        .padding()
    }
}

#Preview {
    ColorSpectrumPreview()
        .frame(width: 350, height: 400)
}
#endif
