//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct PickerImageView: View {
    let imageResource: ImageResource

    @Binding var rgbColor: UIColor

    init(
        imageResource: ImageResource,
        rgbColor: Binding<UIColor>
    ) {
        self.imageResource = imageResource
        self._rgbColor = rgbColor
    }

    var body: some View {
        let image = UIImage(resource: imageResource)
        let aspectRatio: CGFloat = {
            guard image.size.height > 0 else { return 1 }
            return image.size.width / image.size.height
        }()

        Image(imageResource)
            .resizable()
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    pickColor(
                                        from: value.location,
                                        image: image,
                                        viewSize: geometry.size
                                    )
                                }
                        )
                }
            }
    }

    private func pickColor(from location: CGPoint, image: UIImage, viewSize: CGSize) {
        guard let rgb = image.paletteColor(
            at: location,
            in: viewSize
        )?.paletteRGBComponents() else { return }

        rgbColor = UIColor(
            paletteRed: rgb.red,
            green: rgb.green,
            blue: rgb.blue,
            alpha: 255
        )
    }
}

#if DEBUG
private struct PickerImagePreview: View {

    let imageResource: ImageResource

    @State private var rgbColor: UIColor = .red

    var body: some View {
        VStack(spacing: 44) {
            PickerImageView(
                imageResource: imageResource,
                rgbColor: $rgbColor
            )
            Circle()
                .fill(Color(uiColor: rgbColor))
                .frame(width: 44, height: 44)
        }
        .padding()
    }
}

#Preview("Grid") {
    PickerImagePreview(imageResource: .grid)
        .frame(width: 350, height: 400)
}

#Preview("Spectrum") {
    PickerImagePreview(imageResource: .spectrum)
        .frame(width: 350, height: 400)
}
#endif
