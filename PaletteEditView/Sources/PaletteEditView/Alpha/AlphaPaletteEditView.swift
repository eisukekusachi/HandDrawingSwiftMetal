//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

public struct AlphaPaletteEditView: View {
    @ObservedObject private var viewModel: AlphaPaletteEditViewModel

    private let onRemove: (() -> Void)
    private let onDuplicate: (() -> Void)

    public init(
        viewModel: AlphaPaletteEditViewModel,
        onRemove: @escaping (() -> Void),
        onDuplicate: @escaping (() -> Void)
    ) {
        self._viewModel = .init(wrappedValue: viewModel)
        self.onRemove = onRemove
        self.onDuplicate = onDuplicate
    }

    public var body: some View {
        BottomActionToolbar(
            alpha: Binding(
                get: { viewModel.alpha },
                set: { viewModel.updateAlpha($0) }
            ),
            gradientColors: [
                UIColor.black.withAlphaComponent(0),
                UIColor.black.withAlphaComponent(1)
            ],
            isRemoveEnabled: viewModel.canRemoveSelected,
            onRemove: onRemove,
            onDuplicate: onDuplicate
        )
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
private final class PreviewAlphaSource: AlphaPaletteSource {
    @Published var selectedIndex = 0

    var selectedAlpha: Int { 128 }
    var canRemoveSelected: Bool { true }
}

@MainActor
private struct AlphaPalettePreview: View {
    @StateObject private var viewModel: AlphaPaletteEditViewModel

    init() {
        let alphaSource = PreviewAlphaSource()
        _viewModel = StateObject(
            wrappedValue: AlphaPaletteEditViewModel(alphaSource: alphaSource)
        )
    }

    var body: some View {
        AlphaPaletteEditView(
            viewModel: viewModel,
            onRemove: {},
            onDuplicate: {}
        )
        .frame(width: 350)
        .padding()
    }
}

#Preview {
    AlphaPalettePreview()
}
#endif
