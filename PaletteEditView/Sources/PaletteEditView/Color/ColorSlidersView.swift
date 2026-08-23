//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct ColorSlidersView: View {
    @Binding var color: UIColor

    @State private var red = 0
    @State private var green = 0
    @State private var blue = 0

    var body: some View {
        VStack(spacing: 18) {
            HexColorRow(red: red, green: green, blue: blue)
                .padding(.top, 9)

            SliderWithStepper(
                title: "Red",
                value: $red,
                gradientColors: [
                    UIColor(red: 0, green: green, blue: blue, alpha: 255),
                    UIColor(red: 255, green: green, blue: blue, alpha: 255)
                ]
            )

            SliderWithStepper(
                title: "Green",
                value: $green,
                gradientColors: [
                    UIColor(red: red, green: 0, blue: blue, alpha: 255),
                    UIColor(red: red, green: 255, blue: blue, alpha: 255)
                ]
            )

            SliderWithStepper(
                title: "Blue",
                value: $blue,
                gradientColors: [
                    UIColor(red: red, green: green, blue: 0, alpha: 255),
                    UIColor(red: red, green: green, blue: 255, alpha: 255)
                ]
            )
        }
        .onAppear {
            updateSlidersFromColor()
        }
        .onChange(of: color) { _ in
            let components = color.rgbaComponents()
            if components.red != red || components.green != green || components.blue != blue {
                updateSlidersFromColor()
            }
        }
        .onChange(of: red) { _ in updateColorFromSliders() }
        .onChange(of: green) { _ in updateColorFromSliders() }
        .onChange(of: blue) { _ in updateColorFromSliders() }
    }
}

private extension ColorSlidersView {

    func updateSlidersFromColor() {
        let components = color.rgbaComponents()
        red = components.red
        green = components.green
        blue = components.blue
    }

    func updateColorFromSliders() {
        let components = color.rgbaComponents()
        guard
            components.red != red ||
            components.green != green ||
            components.blue != blue
        else { return }

        color = UIColor(
            red: red,
            green: green,
            blue: blue,
            alpha: components.alpha
        )
    }
}

#if DEBUG
private struct ColorSlidersPreview: View {
    @State private var color: UIColor = .red

    var body: some View {
        ColorSlidersView(color: $color)
            .frame(width: 350)
            .padding()
    }
}

#Preview {
    ColorSlidersPreview()
}
#endif
