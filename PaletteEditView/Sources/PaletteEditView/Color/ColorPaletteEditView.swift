//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

/// Popup card height for ``ColorPaletteEditView``.
public let colorPaletteEditViewHeight: CGFloat = 550

public struct ColorPaletteEditView<ColorSource: ColorPaletteColorSource>: View {
    @ObservedObject private var colorSource: ColorSource
    @ObservedObject private var paletteState: ColorPaletteState

    private let onRemove: (() -> Void)?
    private let onDuplicate: (() -> Void)?

    @State private var isApplyingExternalColor = false

    public init(
        colorSource: ColorSource,
        paletteState: ColorPaletteState,
        onRemove: (() -> Void)? = nil,
        onDuplicate: (() -> Void)? = nil
    ) {
        self._colorSource = .init(wrappedValue: colorSource)
        self._paletteState = .init(wrappedValue: paletteState)
        self.onRemove = onRemove
        self.onDuplicate = onDuplicate
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                SegmentPicker(
                    selection: $paletteState.selectedSegment
                )

                Group {
                    switch paletteState.selectedSegment {
                    case .grid:
                        ColorGridView(rgbColor: $paletteState.rgbColor)
                    case .spectrum:
                        ColorSpectrumView(rgbColor: $paletteState.rgbColor)
                    case .sliders:
                        ColorSlidersView(rgbColor: $paletteState.rgbColor)
                    }
                }
            }

            Spacer(minLength: 0)

            AlphaEditSection(
                alpha: Binding(
                    get: { paletteState.alpha },
                    set: { paletteState.updateAlpha($0) }
                ),
                gradientColors: [
                    UIColor(paletteColor: paletteState.rgbColor, alpha: 0),
                    UIColor(paletteColor: paletteState.rgbColor, alpha: 255)
                ],
                onRemove: onRemove,
                onDuplicate: onDuplicate
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            updatePaletteState(from: colorSource.selectedColor)
        }
        .onChange(of: colorSource.selectedIndex) { _ in
            updatePaletteState(from: colorSource.selectedColor)
        }
        .onChange(of: colorSource.selectedColor.paletteRGBAComponents()) { _ in
            updatePaletteState(from: colorSource.selectedColor)
        }
        .onChange(of: paletteState.rgbColor) { _ in
            guard !isApplyingExternalColor else { return }
            paletteState.updateColor()
        }
    }
}

private extension ColorPaletteEditView {
    func updatePaletteState(from color: UIColor) {
        let incoming = color.paletteRGBAComponents()
        let current = paletteState.color.paletteRGBAComponents()
        guard
            incoming.red != current.red
                || incoming.green != current.green
                || incoming.blue != current.blue
                || incoming.alpha != current.alpha
        else { return }

        isApplyingExternalColor = true
        paletteState.setColor(color)
        isApplyingExternalColor = false
    }
}

#if DEBUG
private final class PreviewColorSource: ColorPaletteColorSource {
    @Published var selectedIndex = 0

    var selectedColor: UIColor { .red }
}

private struct ColorPalettePreview: View {
    @StateObject private var paletteState = ColorPaletteState()
    @StateObject private var colorSource = PreviewColorSource()

    var body: some View {
        ColorPaletteEditView(
            colorSource: colorSource,
            paletteState: paletteState
        )
        .frame(width: 350, height: 400)
        .padding()
    }
}

#Preview {
    ColorPalettePreview()
}
#endif
