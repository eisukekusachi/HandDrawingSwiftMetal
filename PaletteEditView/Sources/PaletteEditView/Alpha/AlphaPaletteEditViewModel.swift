//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/08/02.
//

import Combine
import Foundation

@MainActor
public final class AlphaPaletteEditViewModel: ObservableObject {

    @Published public private(set) var alpha: Int

    @Published public private(set) var canRemoveSelected: Bool

    private let alphaSource: any AlphaPaletteSource
    private let onChanged: ((Int) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    public init(
        alphaSource: some AlphaPaletteSource,
        onChanged: ((Int) -> Void)? = nil
    ) {
        self.alphaSource = alphaSource
        self.onChanged = onChanged
        self.alpha = alphaSource.selectedAlpha
        self.canRemoveSelected = alphaSource.canRemoveSelected

        alphaSource.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let `self` else { return }
                    self.setAlpha(self.alphaSource.selectedAlpha)
                    self.canRemoveSelected = self.alphaSource.canRemoveSelected
                }
            }
            .store(in: &cancellables)
    }

    /// Sets the alpha.
    public func setAlpha(_ value: Int) {
        applyAlpha(value)
    }

    /// Sets the alpha and notifies `onChanged`.
    public func updateAlpha(_ value: Int) {
        guard applyAlpha(value) else { return }
        onChanged?(alpha)
    }
}

private extension AlphaPaletteEditViewModel {
    @discardableResult
    func applyAlpha(_ value: Int) -> Bool {
        let clamped = min(max(0, value), 255)
        guard alpha != clamped else { return false }
        alpha = clamped
        return true
    }
}
