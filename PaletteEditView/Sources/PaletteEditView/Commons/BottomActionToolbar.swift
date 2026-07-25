//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct BottomActionToolbar: View {
    private let onRemove: () -> Void
    private let onDuplicate: () -> Void

    private let buttonSize: CGFloat = 22
    private let buttonSpacing: CGFloat = 16
    private let height: CGFloat = 38

    init(
        onRemove: @escaping () -> Void,
        onDuplicate: @escaping () -> Void
    ) {
        self.onRemove = onRemove
        self.onDuplicate = onDuplicate
    }

    var body: some View {
        HStack(alignment: .center, spacing: buttonSpacing) {
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .toolbarIcon(size: buttonSize, color: .systemRed)
            }

            Button(action: onDuplicate) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .toolbarIcon(size: buttonSize)
            }

            Spacer()
        }
        .padding(8)
        .frame(height: height)
    }
}

private extension Image {
    func toolbarIcon(size: CGFloat, color: UIColor = .systemBlue) -> some View {
        resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(Color(uiColor: color))
    }
}

#if DEBUG
#Preview {
    BottomActionToolbar(
        onRemove: {},
        onDuplicate: {}
    )
}
#endif
