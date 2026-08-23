//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct PickerImageView: View {
    private let image: UIImage
    private let aspectRatio: CGFloat

    @Binding var color: UIColor

    init(
        imageResource: ImageResource,
        color: Binding<UIColor>
    ) {
        let image = UIImage(resource: imageResource)
        self.image = image
        self.aspectRatio = image.size.height > 0
            ? image.size.width / image.size.height
            : 1
        self._color = color
    }

    var body: some View {
        Image(uiImage: image)
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
                                        viewSize: geometry.size
                                    )
                                }
                        )
                }
            }
    }

    private func pickColor(from location: CGPoint, viewSize: CGSize) {
        let imageRect = Self.aspectFitRect(imageSize: image.size, in: viewSize)
        guard imageRect.contains(location) else { return }

        let locationInImage = CGPoint(
            x: location.x - imageRect.minX,
            y: location.y - imageRect.minY
        )

        guard let rgb = image.pixelColor(
            at: locationInImage,
            in: imageRect.size
        )?.rgbaComponents() else { return }

        let alpha = color.rgbaComponents().alpha
        color = UIColor(
            red: rgb.red,
            green: rgb.green,
            blue: rgb.blue,
            alpha: alpha
        )
    }

    private static func aspectFitRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard
            imageSize.width > 0,
            imageSize.height > 0,
            containerSize.width > 0,
            containerSize.height > 0
        else {
            return .zero
        }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            let width = containerSize.width
            let height = width / imageAspect
            let y = (containerSize.height - height) / 2
            return CGRect(x: 0, y: y, width: width, height: height)
        } else {
            let height = containerSize.height
            let width = height * imageAspect
            let x = (containerSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        }
    }
}

#if DEBUG
private struct PickerImagePreview: View {

    let imageResource: ImageResource

    @State private var color: UIColor = .red

    var body: some View {
        VStack(spacing: 44) {
            PickerImageView(
                imageResource: imageResource,
                color: $color
            )
            Circle()
                .fill(Color(uiColor: color))
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
