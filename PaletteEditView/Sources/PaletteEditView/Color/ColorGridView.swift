//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct ColorGridView: View {
    @Binding var color: UIColor

    var body: some View {
        PickerImageView(
            imageName: "grid",
            color: $color
        )
    }
}

#if DEBUG
private struct ColorGridPreview: View {
    @State private var color: UIColor = .red

    var body: some View {
        VStack(spacing: 44) {
            ColorGridView(color: $color)
                .frame(height: 360)

            Circle()
                .fill(Color(uiColor: color))
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
