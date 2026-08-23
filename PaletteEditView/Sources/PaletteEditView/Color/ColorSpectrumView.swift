//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct ColorSpectrumView: View {
    @Binding var color: UIColor

    var body: some View {
        PickerImageView(
            imageName: "spectrum",
            color: $color
        )
    }
}

#if DEBUG
private struct ColorSpectrumPreview: View {
    @State private var color: UIColor = .red

    var body: some View {
        VStack(spacing: 44) {
            ColorSpectrumView(color: $color)
                .frame(height: 360)
            Circle()
                .fill(Color(uiColor: color))
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
