//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/08/02.
//

import Combine
import Foundation
import UIKit

@MainActor
public final class ColorPaletteEditViewModel: ObservableObject {

    @Published public var selectedSegment: ColorPaletteSegment = .grid

    @Published public private(set) var color: UIColor

    @Published public private(set) var canRemoveSelected: Bool

    private let colorSource: any ColorPaletteSource
    private let onChanged: ((UIColor) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    public init(
        colorSource: some ColorPaletteSource,
        onChanged: ((UIColor) -> Void)? = nil
    ) {
        self.colorSource = colorSource
        self.onChanged = onChanged
        self.color = colorSource.selectedColor
        self.canRemoveSelected = colorSource.canRemoveSelected

        colorSource.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let `self` else { return }
                    self.setColor(self.colorSource.selectedColor)
                    self.canRemoveSelected = self.colorSource.canRemoveSelected
                }
            }
            .store(in: &cancellables)
    }

    /// Sets the color.
    public func setColor(_ color: UIColor) {
        applyColor(color)
    }

    /// Sets the color and notifies `onChanged`.
    public func updateColor(_ color: UIColor) {
        guard applyColor(color) else { return }
        onChanged?(self.color)
    }
}

private extension ColorPaletteEditViewModel {
    @discardableResult
    func applyColor(_ color: UIColor) -> Bool {
        let components = color.rgbaComponents()
        guard components != self.color.rgbaComponents() else { return false }

        self.color = UIColor(
            intRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
        return true
    }
}
