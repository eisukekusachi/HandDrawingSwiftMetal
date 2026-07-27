//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

struct ColorSlidersView: View {
    @Binding var rgbColor: UIColor

    @State private var red = 0
    @State private var green = 0
    @State private var blue = 0

    var body: some View {
        VStack(spacing: 18) {
            HexColorRow(red: red, green: green, blue: blue)

            SliderWithStepper(
                title: "Red",
                value: $red,
                gradientColors: [
                    UIColor(paletteRed: 0, green: green, blue: blue, alpha: 255),
                    UIColor(paletteRed: 255, green: green, blue: blue, alpha: 255)
                ]
            )

            SliderWithStepper(
                title: "Green",
                value: $green,
                gradientColors: [
                    UIColor(paletteRed: red, green: 0, blue: blue, alpha: 255),
                    UIColor(paletteRed: red, green: 255, blue: blue, alpha: 255)
                ]
            )

            SliderWithStepper(
                title: "Blue",
                value: $blue,
                gradientColors: [
                    UIColor(paletteRed: red, green: green, blue: 0, alpha: 255),
                    UIColor(paletteRed: red, green: green, blue: 255, alpha: 255)
                ]
            )
        }
        .onAppear {
            updateSlidersFromColor()
        }
        .onChange(of: rgbColor) { _ in
            let components = rgbColor.paletteRGBAComponents()
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
        let components = rgbColor.paletteRGBAComponents()
        red = components.red
        green = components.green
        blue = components.blue
    }

    func updateColorFromSliders() {
        let updated = UIColor(paletteRed: red, green: green, blue: blue, alpha: 255)
        let current = rgbColor.paletteRGBAComponents()
        if current.red != red || current.green != green || current.blue != blue {
            rgbColor = updated
        }
    }
}

#if DEBUG
private struct ColorSlidersPreview: View {
    @State private var rgbColor: UIColor = .red

    var body: some View {
        ColorSlidersView(rgbColor: $rgbColor)
            .frame(width: 350)
            .padding()
    }
}

#Preview {
    ColorSlidersPreview()
}
#endif
