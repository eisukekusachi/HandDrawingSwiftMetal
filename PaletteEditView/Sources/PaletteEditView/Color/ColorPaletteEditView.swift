//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

public struct ColorPaletteEditView: View {
    @ObservedObject private var viewModel: ColorPaletteEditViewModel

    private let onRemove: (() -> Void)
    private let onDuplicate: (() -> Void)

    public init(
        viewModel: ColorPaletteEditViewModel,
        onRemove: @escaping (() -> Void),
        onDuplicate: @escaping (() -> Void)
    ) {
        self._viewModel = .init(wrappedValue: viewModel)
        self.onRemove = onRemove
        self.onDuplicate = onDuplicate
    }

    public var body: some View {
        VStack(spacing: 16) {
            SegmentPicker(
                selection: $viewModel.selectedSegment
            )

            ZStack(alignment: .top) {
                segmentContent(isSelected: viewModel.selectedSegment == .grid) {
                    ColorGridView(color: colorBinding)
                }

                segmentContent(isSelected: viewModel.selectedSegment == .spectrum) {
                    ColorSpectrumView(color: colorBinding)
                }

                segmentContent(isSelected: viewModel.selectedSegment == .sliders) {
                    ColorSlidersView(color: colorBinding)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)

            BottomActionToolbar(
                alpha: alphaBinding,
                gradientColors: [
                    UIColor(color: viewModel.color, alpha: 0),
                    UIColor(color: viewModel.color, alpha: 255)
                ],
                isRemoveEnabled: viewModel.canRemoveSelected,
                onRemove: onRemove,
                onDuplicate: onDuplicate
            )
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func segmentContent(
        isSelected: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        content()
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }

    private var colorBinding: Binding<UIColor> {
        Binding(
            get: { viewModel.color },
            set: { viewModel.updateColor($0) }
        )
    }

    private var alphaBinding: Binding<Int> {
        Binding(
            get: { viewModel.color.rgbaComponents().alpha },
            set: { alpha in
                viewModel.updateColor(
                    UIColor(color: viewModel.color, alpha: alpha)
                )
            }
        )
    }
}

#if DEBUG
private final class PreviewColorSource: ColorPaletteSource {
    @Published var selectedIndex = 0

    var selectedColor: UIColor { .red }
    var canRemoveSelected: Bool { true }
}

private struct ColorPalettePreview: View {
    @StateObject private var viewModel: ColorPaletteEditViewModel

    init() {
        let colorSource = PreviewColorSource()
        _viewModel = StateObject(
            wrappedValue: ColorPaletteEditViewModel(colorSource: colorSource)
        )
    }

    var body: some View {
        ColorPaletteEditView(
            viewModel: viewModel,
            onRemove: {},
            onDuplicate: {}
        )
        .frame(width: 350, height: 500)
        .padding()
    }
}

#Preview {
    ColorPalettePreview()
}
#endif
