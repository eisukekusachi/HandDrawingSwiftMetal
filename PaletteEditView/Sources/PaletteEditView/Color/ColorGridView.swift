//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct ColorGridView: View {
    @Binding var rgbColor: UIColor

    var body: some View {
        PickerImageView(
            imageResource: .grid,
            rgbColor: $rgbColor
        )
    }
}

#if DEBUG
private struct ColorGridPreview: View {
    @State private var rgbColor: UIColor = .red

    var body: some View {
        VStack(spacing: 44) {
            ColorGridView(rgbColor: $rgbColor)
                .frame(height: 360)

            Circle()
                .fill(Color(uiColor: rgbColor))
                .frame(width: 44, height: 44)
        }
        .padding()
    }
}

#Preview {
    ColorGridPreview()
        .frame(width: 350, height: 400)
}
#endif
