//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

/// Layout sizes for SwiftUI's Liquid Glass slider handle.
private enum GradientSliderLayout {
    static let uniformInset: CGFloat = 4
    static let thumbSize: CGFloat = 20

    static var trackHeight: CGFloat { thumbSize + uniformInset * 2 }
}

struct GradientSlider: View {
    @Binding var value: Int

    private let gradientColors: [UIColor]

    init(
        value: Binding<Int>,
        gradientColors: [UIColor]
    ) {
        self._value = value
        self.gradientColors = gradientColors
    }

    var body: some View {
        ZStack {
            trackBackground

            GradientSliderControl(value: $value)
                .padding(.horizontal, GradientSliderLayout.uniformInset)
        }
        .frame(height: GradientSliderLayout.trackHeight)
    }
}

private extension GradientSlider {
    var trackBackground: some View {
        ZStack {
            CheckerboardBackground()
            LinearGradient(
                colors: gradientColors.map { Color(uiColor: $0) },
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .clipShape(Capsule())
    }
}

/// Uses `UISlider` so the system track stays hidden while keeping the Liquid Glass handle.
private struct GradientSliderControl: UIViewRepresentable {
    @Binding var value: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 255
        slider.minimumTrackTintColor = .clear
        slider.maximumTrackTintColor = .clear
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        let targetValue = Float(value)
        let boundsChanged = context.coordinator.lastBounds != slider.bounds
        context.coordinator.lastBounds = slider.bounds

        guard !slider.isTracking else { return }

        if slider.value != targetValue || boundsChanged {
            slider.setValue(targetValue, animated: false)
        }
    }

    final class Coordinator: NSObject {
        private var value: Binding<Int>
        var lastBounds: CGRect = .zero

        init(value: Binding<Int>) {
            self.value = value
        }

        @MainActor
        @objc func valueChanged(_ sender: UISlider) {
            value.wrappedValue = Int(sender.value.rounded())
        }
    }
}

private struct CheckerboardBackground: View {
    private let patternSize: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            let light = Color.white
            let dark = Color(white: 0.92)

            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let isLight = (Int(x / patternSize) + Int(y / patternSize)).isMultiple(of: 2)
                    let rect = CGRect(x: x, y: y, width: patternSize, height: patternSize)
                    context.fill(Path(rect), with: .color(isLight ? light : dark))
                    x += patternSize
                }
                y += patternSize
            }
        }
    }
}

#if DEBUG
private struct GradientSliderPreview: View {
    @State private var value = 255

    var body: some View {
        GradientSlider(
            value: $value,
            gradientColors: [
                UIColor(paletteRed: 0, green: 0, blue: 0, alpha: 255),
                UIColor(paletteRed: 255, green: 0, blue: 0, alpha: 255)
            ]
        )
        .padding()
    }
}

#Preview {
    GradientSliderPreview()
}
#endif
