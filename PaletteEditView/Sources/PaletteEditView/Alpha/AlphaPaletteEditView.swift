//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

/// Popup card height for ``AlphaPaletteEditView``.
public let alphaPaletteEditViewHeight: CGFloat = 190

public struct AlphaPaletteEditView<AlphaSource: AlphaPaletteAlphaSource>: View {
    @ObservedObject private var alphaSource: AlphaSource
    @ObservedObject private var paletteState: AlphaPaletteState

    private let onRemove: (() -> Void)?
    private let onDuplicate: (() -> Void)?

    public init(
        alphaSource: AlphaSource,
        paletteState: AlphaPaletteState,
        onRemove: (() -> Void)? = nil,
        onDuplicate: (() -> Void)? = nil
    ) {
        self._alphaSource = .init(wrappedValue: alphaSource)
        self._paletteState = .init(wrappedValue: paletteState)
        self.onRemove = onRemove
        self.onDuplicate = onDuplicate
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            BottomActionToolbar(
                alpha: Binding(
                    get: { paletteState.alpha },
                    set: { paletteState.updateAlpha($0) }
                ),
                gradientColors: [
                    UIColor.black.withAlphaComponent(0),
                    UIColor.black.withAlphaComponent(1)
                ],
                onRemove: onRemove,
                onDuplicate: onDuplicate
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            updatePaletteState(from: alphaSource.selectedAlpha)
        }
        .onChange(of: alphaSource.selectedIndex) { _ in
            updatePaletteState(from: alphaSource.selectedAlpha)
        }
        .onChange(of: alphaSource.selectedAlpha) { _ in
            updatePaletteState(from: alphaSource.selectedAlpha)
        }
    }
}

private extension AlphaPaletteEditView {
    func updatePaletteState(from alpha: Int) {
        guard paletteState.alpha != alpha else { return }
        paletteState.setAlpha(alpha)
    }
}

#if DEBUG
private final class PreviewAlphaSource: AlphaPaletteAlphaSource {
    @Published var selectedIndex = 0

    var selectedAlpha: Int { 128 }
}

private struct AlphaPalettePreview: View {
    @StateObject private var paletteState = AlphaPaletteState()
    @StateObject private var alphaSource = PreviewAlphaSource()

    var body: some View {
        AlphaPaletteEditView(
            alphaSource: alphaSource,
            paletteState: paletteState
        )
        .frame(width: 350, height: 200)
        .padding()
    }
}

#Preview {
    AlphaPalettePreview()
}
#endif
