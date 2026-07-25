//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/25.
//

import SwiftUI

struct HexColorRow: View {
    private let red: Int
    private let green: Int
    private let blue: Int

    private let height: CGFloat = 20

    init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    var body: some View {
        HStack {
            Text("Hex Color")

            Spacer()

            Text(
                "#" + String(format: "%02X%02X%02X", red, green, blue)
            )
        }
        .font(.system(size: 14))
        .frame(height: height)
    }
}

#if DEBUG
#Preview {
    HexColorRow(red: 255, green: 64, blue: 128)
        .padding()
}
#endif
